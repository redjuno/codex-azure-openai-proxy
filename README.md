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

AZURE_DEPLOYMENT_OPUS=your-primary-deployment
AZURE_DEPLOYMENT_FABLE=your-secondary-deployment

LITELLM_HOST=127.0.0.1
LITELLM_PORT=4000
LITELLM_MASTER_KEY=sk-local-codex-proxy

CODEX_MODEL_OPUS_ALIAS=opus
CODEX_MODEL_FABLE_ALIAS=fable
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

- `OPENAI_BASE_URL=http://127.0.0.1:4000/v1`
- `OPENAI_API_KEY=$LITELLM_MASTER_KEY`
- OpenAI Responses wire
- 기본 모델 alias

기존 `~/.codex/config.toml`, 인증 정보, 플러그인, 권한 설정은 수정하지 않습니다.

두 Azure deployment는 LiteLLM alias로 노출됩니다. 기본 모델은 `CODEX_MODEL_OPUS_ALIAS`이며, Codex 인자에 `-m`을 주면 해당 값을 사용합니다.

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

