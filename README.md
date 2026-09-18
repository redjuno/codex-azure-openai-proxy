# Codex Azure OpenAI Proxy

Codex CLI를 로컬 LiteLLM 프록시를 통해 Azure OpenAI에 연결하는 실행 템플릿입니다.

```
Codex CLI -> LiteLLM proxy -> Azure OpenAI Responses API
```

## 빠른 시작

필요한 명령을 확인합니다.

```bash
codex --version
uvx --version
curl --version
make --version
```

설정 파일을 만들고 Azure 값을 입력합니다.

```bash
make setup
```

`.env`:

```dotenv
AZURE_API_KEY=your-azure-openai-key
AZURE_API_BASE=https://your-resource.openai.azure.com
AZURE_API_VERSION=2025-03-01-preview

AZURE_DEPLOYMENT_SOL=your-gpt-56-sol-deployment
AZURE_DEPLOYMENT_ASTRA=your-gpt-6-astra-deployment
AZURE_DEPLOYMENT_LUNA=your-gpt-56-luna-deployment

LITELLM_HOST=127.0.0.1
LITELLM_PORT=4020
LITELLM_MASTER_KEY=sk-local-codex-proxy

CODEX_MODEL_SOL_ALIAS=gpt-5.6-sol
CODEX_MODEL_ASTRA_ALIAS=gpt-6-astra
CODEX_MODEL_LUNA_ALIAS=gpt-5.6-luna
```

연결과 lifecycle을 확인합니다.

```bash
make doctor
make test-lifecycle
make alias
source ~/.zshrc
```

어떤 프로젝트에서든 실행합니다.

```bash
cd /path/to/your/project
codex-azure
```

`codex-azure`는 현재 디렉터리에서 Codex를 실행하고, 필요한 경우 LiteLLM을 시작합니다. 마지막 세션이 끝나면 이 런처가 시작한 프록시만 종료합니다.

## 동작 방식

런처는 실행 시 Codex 설정 오버라이드를 주입합니다.

- `OPENAI_BASE_URL=http://127.0.0.1:4020/v1`
- `OPENAI_API_KEY=$LITELLM_MASTER_KEY`
- OpenAI Responses wire
- 기본 모델 alias

기존 `~/.codex/config.toml`, 인증 정보, 플러그인, 권한 설정은 수정하지 않습니다.

세 Azure deployment가 LiteLLM alias로 노출됩니다.

| `.env` 키 | Azure deployment | Codex가 보는 모델 이름 |
| --- | --- | --- |
| `AZURE_DEPLOYMENT_SOL` | `gpt-sol` | `CODEX_MODEL_SOL_ALIAS` (기본 `gpt-5.6-sol`) |
| `AZURE_DEPLOYMENT_ASTRA` | `gpt-astra` | `CODEX_MODEL_ASTRA_ALIAS` (기본 `gpt-6-astra`) |
| `AZURE_DEPLOYMENT_LUNA` | `gpt-luna` | `CODEX_MODEL_LUNA_ALIAS` (기본 `gpt-5.6-luna`) |

`-m` 없이 실행하면 SOL alias를 사용합니다. 다른 모델은 `codex-azure -m gpt-6-astra`처럼 지정합니다.

모델을 추가하려면 `.env`에 `AZURE_DEPLOYMENT_<KEY>`와 `CODEX_MODEL_<KEY>_ALIAS`를 넣고, `scripts/ensure-env.sh`의 `CODEX_MODEL_KEYS`에 키를 추가한 뒤 `config/litellm.config.yaml`에 같은 형태의 블록을 하나 더 둡니다.

Codex TUI의 `/model` 목록에는 이 alias들이 뜨지 않습니다. Codex가 프록시의 `/v1/models`를 조회하지만 `{"models": [...]}` 형태를 기대하고, LiteLLM은 OpenAI 표준인 `{"data": [...]}`로 응답하기 때문입니다. `-m`으로 지정하는 경로는 정상 동작합니다.

수동 실행도 가능합니다.

```bash
make proxy
make test
make status
make stop
```

`make test-lifecycle`은 mock 프록시와 mock Codex만 사용하므로 Azure 요청이나 모델 비용이 발생하지 않습니다.

## Azure 설정 주의사항

- `AZURE_API_BASE`는 Azure OpenAI resource endpoint입니다.
- deployment 변수에는 모델 ID가 아니라 Azure deployment name을 넣습니다.
- Responses API를 사용하므로 `AZURE_API_VERSION`은 `2025-03-01-preview` 이상을 사용합니다.
- `LITELLM_MASTER_KEY`는 로컬 프록시 인증 키이며 Azure 키가 아닙니다.
- `LITELLM_HOST`는 기본값 `127.0.0.1`을 유지하세요.
- `LITELLM_PORT`는 다른 프로세스가 쓰지 않는 포트를 고르세요. Docker가 4000을, 같은 방식의 Claude Code 프록시가 4010을 쓰는 경우가 많습니다.
- Claude Code 프록시와 함께 쓴다면 `LITELLM_PORT`와 `LITELLM_MASTER_KEY`를 서로 다르게 두세요. 값이 같으면 이 런처가 그 프록시를 "호환되는 외부 프록시"로 보고 재사용하며, alias가 달라 model not found로 실패합니다.
- Azure API key는 `.env`에만 두고 Git에 커밋하지 마세요.
- 모델 오류가 나면 먼저 `make test`로 프록시를 확인한 뒤 Codex를 실행하세요.

## 파일 구조

```
config/litellm.config.yaml   LiteLLM 모델 매핑
scripts/start-proxy.sh       프록시 시작
scripts/proxy-runtime.sh     프록시 lifecycle
scripts/codex-via-azure-openai.sh  Codex launcher
scripts/install-alias.sh     codex-azure 설치
tests/test-lifecycle.sh      mock 기반 lifecycle 테스트
```

