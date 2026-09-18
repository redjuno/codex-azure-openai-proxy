# 진행 상태

원격 저장소: https://github.com/redjuno/codex-azure-openai-proxy

## 완료된 작업

- Claude용 기존 레포를 기반으로 Codex 전용 새 레포 생성
- LiteLLM을 통한 Azure OpenAI Responses API 프록시 구성
- scripts/codex-via-azure-openai.sh 런처 구현
  - OPENAI_BASE_URL, OPENAI_API_KEY 설정
  - Codex provider/model/Responses 설정을 실행 시 -c 옵션으로 주입
  - 기존 ~/.codex/config.toml을 수정하지 않음
- 프록시 자동 lifecycle
  - 자동 시작
  - 동시 세션 공유
  - 마지막 세션 종료 시 managed proxy 종료
  - 외부에서 실행 중인 호환 proxy 재사용
- codex-azure alias/shim 설치
- make setup, make proxy, make test, make status, make stop, make doctor 제공
- 기존 Claude 전용 설정과 문서 제거
- mock Codex와 mock proxy를 사용하는 lifecycle 테스트 추가
- shell syntax check 및 make test-lifecycle 통과
- GitHub public repository 생성 및 main push 완료
- Codex 전용 .env 분리 (issue #1): 포트 4020, master key sk-local-codex-proxy, CODEX_MODEL_*_ALIAS 정의, CLAUDE_CODE_* 잔재 제거
- proxy-runtime.sh 직접 실행 시 ROOT_DIR 미설정 버그 수정 (make status/stop이 /.codex-runtime을 만들려다 lock 루프에 갇혔음)
- 실제 Azure Responses API 연결 검증 완료 (아래 실측 결과)

## 현재 사용 방법

Codex 레포에서:

~~~bash
make setup
~~~

.env에 다음 값을 입력합니다.

~~~dotenv
AZURE_API_KEY=
AZURE_API_BASE=https://your-resource.openai.azure.com
AZURE_API_VERSION=2025-03-01-preview
AZURE_DEPLOYMENT_SOL=
AZURE_DEPLOYMENT_ASTRA=
AZURE_DEPLOYMENT_LUNA=
LITELLM_MASTER_KEY=sk-local-codex-proxy
~~~

그 다음:

~~~bash
make test-lifecycle
make alias
source ~/.zshrc
cd /path/to/project
codex-azure
~~~

## 실측 검증 결과 (2026-09-18)

환경: Codex CLI 0.154.0, uvx 0.7.18, Azure `aoai-jh-krc-01`, api-version `2025-03-01-preview`.

확인된 것:

- `make test` — 노출 alias 전부 `/v1/responses` 200 + `output_text` 반환. issue #3 이후로는 `gpt-5.6-sol`(`gpt-sol`), `gpt-6-astra`(`gpt-astra`), `gpt-5.6-luna`(`gpt-luna`) 세 개
- streaming — SSE `response.output_text.delta` 9건 포함, `response.completed`까지 정상 종료
- function tool call — `get_weather` 스펙 전달 시 `function_call` + `{"city":"Seoul"}` 인자 반환. `azure/responses/` 라우팅과 `base_model: azure/gpt-5` 설정이 의도대로 동작
- Codex 실전 — `codex exec`로 셸 tool call 왕복 성공, managed proxy 자동 시작(4020) 및 세션 종료 시 자동 종료 확인
- 격리 — Claude Code 프록시(4010)는 영향 없음, 종료 후 `make status`는 `stopped`, 활성 세션 0

## 모델 설정 키 (issue #3)

deployment와 alias 변수를 모델 별칭 기준으로 다시 명명하고, 쓰이지 않던 `gpt-luna`까지 노출했습니다.

| `.env` 키 | Azure deployment | Codex가 보는 이름 |
| --- | --- | --- |
| `AZURE_DEPLOYMENT_SOL` | `gpt-sol` | `gpt-5.6-sol` (기본 모델) |
| `AZURE_DEPLOYMENT_ASTRA` | `gpt-astra` | `gpt-6-astra` |
| `AZURE_DEPLOYMENT_LUNA` | `gpt-luna` | `gpt-5.6-luna` |

모델 목록은 `scripts/ensure-env.sh`의 `CODEX_MODEL_KEYS` 한 곳에서 나오고, `start-proxy.sh`와 `test-proxy.sh`가 그 배열을 순회합니다. 이전 이름(`OPUS`, `FABLE`)과 별칭(`opus`, `fable`)은 남아 있지 않습니다.

Codex TUI `/model` 목록에는 아직 안 뜹니다. `codex_models_manager`가 `{"models": [...]}`를 기대하는데 LiteLLM은 `{"data": [...]}`로 응답해서 목록 갱신이 실패하고 내장 프리셋만 남습니다. `-m` 지정 경로는 정상입니다. 별도 작업으로 다룹니다.

## 포트/키 충돌 주의 (issue #1에서 실제로 발생)

이 레포의 `.env`는 Claude 레포 `.env` 복사본이라 포트 4010과 master key가 그대로였다. 4010에는 이미 Claude 프록시가 떠 있어서 `proxy_ensure_locked`가 그것을 "호환되는 외부 프록시"로 재사용했고, 노출 alias가 달라 Azure 도달 전에 model not found로 실패했다. 기본값 4000도 Docker가 점유 중이었다.

두 프록시를 함께 쓸 때는 `LITELLM_PORT`와 `LITELLM_MASTER_KEY`를 반드시 다르게 둔다.

## 아직 필요한 작업

- Codex CLI 버전 업그레이드 시 `-c model_providers.codex-azure.*` override 형식 재확인 (0.154.0에서는 유효)
- Azure Entra ID 인증이 필요해지면 별도 작업으로 추가
- 장시간 세션에서 프록시 안정성 관찰 (`.codex-runtime/proxy.log`)
- API key는 `.env`에만 두고 커밋하지 않기, `LITELLM_HOST=127.0.0.1` 유지

## 의도적으로 제외한 범위

- Claude와 Codex를 하나의 레포에서 통합
- Entra ID/managed identity 인증
- 원격 공용 proxy 운영
- 모델별 복잡한 routing
- 새로운 Python/Node dependency 추가

