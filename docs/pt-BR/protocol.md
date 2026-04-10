# Protocolo HTTP do DelphiTestAgent

[English](../en/protocol.md) | [Português (BR)](protocol.md) | [Español](../es/protocol.md)

O agente expõe uma pequena API HTTP estilo REST em `127.0.0.1:8765`
(configurável). Todas as respostas são `application/json; charset=utf-8`.
Autenticação é opcional via header `X-Agent-Token`.

## Endpoints

### GET /health
Sonda de vida (liveness probe).

Resposta:
```
{"status":"ok","agent":"DelphiTestAgent","version":"0.1.0"}
```

### GET /tree
Árvore completa de componentes de todas as forms visíveis em `Screen.Forms`.
Recursivo até `Config.MaxDepth` (padrão 20).

Formato da resposta:
```
{
  "application": "MyApp",
  "mainForm": "FormMain",
  "forms": [
    {
      "name": "FormMain",
      "class": "TFormMain",
      "bounds": {"left":200,"top":120,"width":480,"height":320,"visible":true},
      "props": { "Caption": "...", "Enabled": "True", ... },
      "children": [ ... ]
    }
  ]
}
```

### GET /components
Lista plana de `Name:ClassName` para descoberta rápida.

Resposta:
```
{"components":["FormMain:TFormMain","btnCalcular:TButton",...]}
```

### GET /dump/:name
Dump de uma subárvore de um componente pelo Name.

### GET /get/:component/:property
Lê uma propriedade publicada via `TypInfo.GetPropValue`.

Sucesso:
```
{"component":"edNome","property":"Text","value":"Joao"}
```

Erro:
```
{"component":"edNome","property":"Text","error":"..."}
```

### POST /set
Escreve uma propriedade publicada via `TypInfo.SetPropValue`. Aceita strings;
a conversão RTTI trata inteiros, enums, booleans, etc.

Body:
```
{"component":"edNome","property":"Text","value":"Joao"}
```

Resposta:
```
{"component":"edNome","property":"Text","value":"Joao","status":"ok"}
```

### POST /click
Invoca `OnClick` do componente nomeado via `TypInfo.GetMethodProp`. Roda na
main thread via `TThread.Synchronize`.

Body: `{"component":"btnCalcular"}`
Resposta: `{"component":"btnCalcular","event":"OnClick","status":"invoked"}`

### POST /invoke
Invoca qualquer `TNotifyEvent` publicado no componente.

Body: `{"component":"edValor","event":"OnExit"}`

### POST /focus
Chama `SetFocus` no componente se ele descende de `TWinControl`.

Body: `{"component":"edNome"}`

### POST /sendkey
Posta par `WM_KEYDOWN`/`WM_KEYUP` (para virtual keys) ou `WM_CHAR` (para
caracteres) na janela focada. Aceita:
- Caractere único: `"A"`, `"5"`
- Nomes de VK: `VK_RETURN`, `VK_TAB`, `VK_ESCAPE`, `VK_SPACE`, `VK_BACK`,
  `VK_DELETE`, `VK_F1`..`VK_F6`, `VK_UP`, `VK_DOWN`, `VK_LEFT`, `VK_RIGHT`

Body: `{"key":"VK_RETURN"}`

## Autenticação

Se `Config.Token` estiver definido, toda requisição precisa incluir o header
`X-Agent-Token: <token>`. Requisições sem o token retornam HTTP 401.

## Erros

Todos os erros retornam JSON com campo `error` e HTTP 500 (exceto 401 para
falha de autenticação, 404 para paths desconhecidos).

## Thread safety

O servidor HTTP usa Indy com suas próprias threads de worker. Todas as
leituras/escritas RTTI e invocações de eventos são marshaladas para a main
thread do VCL via `TThread.Synchronize`. Isso significa:

- Dumps RTTI podem demorar se o app estiver ocupado na main thread.
- Invocações de eventos rodam sincronamente do ponto de vista do chamador.
- Eventos long-running bloqueiam a resposta HTTP.
