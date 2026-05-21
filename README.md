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
