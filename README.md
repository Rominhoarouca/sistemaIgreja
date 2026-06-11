# Sistema Igreja

Projeto de recepcao e integracao de visitantes em celulas, com aplicativo Flutter e API REST em Node.js/TypeScript.

## Documentacao em formato Book

Para manter o README enxuto, toda a documentacao detalhada foi organizada em capitulos:

- [Book de Documentacao](docs/book/README.md)
- [Summary do Book](docs/book/SUMMARY.md)

Conteudo incluido no book:

- Funcionalidades por perfil (Admin, Lider e fluxo de Visitante)
- Mapa completo da API REST
- Arquitetura frontend e backend
- Diagramas de DER, Sequencia e Classes
- Galeria com imagens da identidade visual do app
- Guia de execucao e operacao

## Execucao rapida

### App Flutter

```bash
flutter pub get
flutter run
```

### API

```bash
cd api
npm install
npx prisma generate
npx prisma migrate dev
npm run dev
```

## Publicar PWA (App web)

Esta base contém um fluxo para gerar o build do Flutter Web localmente, pré-comprimir os ativos e empacotar em uma imagem Docker multi-arquitetura pronta para push.

- Arquivos importantes:
	- `api/package.json` — script `publishAPP` que executa o fluxo localmente.
	- `scripts/precompress_web.sh` — gera `.gz` e `.br` em `build/web`.
	- `Dockerfile.web` — Dockerfile que serve o conteúdo de `build/web`.

1) Testar localmente (requer `flutter`, `docker buildx` e `brotli` instalados):

```bash
# via npm (args passados diretamente ao script publish_app.sh)
npm --prefix api run publishAPP -- --tag=0.0.2 --api_base_url="https://minha.api/v1"

# ou via variáveis de ambiente
TAG=0.0.2 API_BASE_URL="https://minha.api/v1" npm --prefix api run publishAPP

# ou direto pelo script
bash scripts/publish_app.sh --tag=0.0.2 --api_base_url="https://minha.api/v1"
```

Observações:
- `--tag` define a tag da imagem Docker; padrão: `latest`.
- `--api_base_url` define a URL base da API embutida no build; padrão: placeholder substituído em runtime pelo `entrypoint.sh`.

2) CI (GitHub Actions)

Um workflow está disponível em `.github/workflows/publish_app.yml`. Ele:
- Faz checkout do código;
- Configura Flutter (runner nativo) e executa `flutter build web` com `--dart-define=API_BASE_URL`;
- Executa `./scripts/precompress_web.sh build/web`;
- Faz login no Docker Hub e publica a imagem multi-arch usando a `tag` do push (refs/tags/v*) ou o `tag` fornecido manualmente.

Secrets necessários no repositório para o workflow:
- `DOCKERHUB_USERNAME` — usuário Docker Hub;
- `DOCKERHUB_TOKEN` — token/password para login no Docker Hub;
- `API_BASE_URL` — (opcional) URL base da API usada no build se não fornecida manualmente.

Uso do workflow:
- Push de uma tag `vX.Y.Z` aciona a publicação usando `X.Y.Z` como tag da imagem.
- Ou faça `Actions -> Publish Flutter Web App -> Run workflow` e informe `tag` e `api_base_url`.

