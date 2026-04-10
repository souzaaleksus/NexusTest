# Protocolo HTTP del DelphiTestAgent

[English](../en/protocol.md) | [Português (BR)](../pt-BR/protocol.md) | [Español](protocol.md)

El agente expone una pequeña API HTTP estilo REST en `127.0.0.1:8765`
(configurable). Todas las respuestas son `application/json; charset=utf-8`.
La autenticación es opcional vía el header `X-Agent-Token`.

## Endpoints

### GET /health
Sonda de vida (liveness probe).

Respuesta:
```
{"status":"ok","agent":"DelphiTestAgent","version":"0.1.0"}
```

### GET /tree
Árbol completo de componentes de todos los forms visibles en `Screen.Forms`.
Recursivo hasta `Config.MaxDepth` (por defecto 20).

Forma de la respuesta:
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
Lista plana de `Name:ClassName` para descubrimiento rápido.

Respuesta:
```
{"components":["FormMain:TFormMain","btnCalcular:TButton",...]}
```

### GET /dump/:name
Dump de un subárbol de un componente por Name.

### GET /get/:component/:property
Lee una propiedad publicada vía `TypInfo.GetPropValue`.

Éxito:
```
{"component":"edNome","property":"Text","value":"Juan"}
```

Error:
```
{"component":"edNome","property":"Text","error":"..."}
```

### POST /set
Escribe una propiedad publicada vía `TypInfo.SetPropValue`. Acepta strings;
la conversión RTTI maneja enteros, enums, booleans, etc.

Body:
```
{"component":"edNome","property":"Text","value":"Juan"}
```

Respuesta:
```
{"component":"edNome","property":"Text","value":"Juan","status":"ok"}
```

### POST /click
Invoca `OnClick` del componente nombrado vía `TypInfo.GetMethodProp`.
Se ejecuta en el main thread vía `TThread.Synchronize`.

Body: `{"component":"btnCalcular"}`
Respuesta: `{"component":"btnCalcular","event":"OnClick","status":"invoked"}`

### POST /invoke
Invoca cualquier `TNotifyEvent` publicado en el componente.

Body: `{"component":"edValor","event":"OnExit"}`

### POST /focus
Llama a `SetFocus` en el componente si desciende de `TWinControl`.

Body: `{"component":"edNome"}`

### POST /sendkey
Envía un par `WM_KEYDOWN`/`WM_KEYUP` (para virtual keys) o `WM_CHAR` (para
caracteres) a la ventana enfocada. Acepta:
- Un solo carácter: `"A"`, `"5"`
- Nombres de VK: `VK_RETURN`, `VK_TAB`, `VK_ESCAPE`, `VK_SPACE`, `VK_BACK`,
  `VK_DELETE`, `VK_F1`..`VK_F6`, `VK_UP`, `VK_DOWN`, `VK_LEFT`, `VK_RIGHT`

Body: `{"key":"VK_RETURN"}`

## Autenticación

Si `Config.Token` está configurado, cada request debe incluir el header
`X-Agent-Token: <token>`. Los requests sin token retornan HTTP 401.

## Errores

Todos los errores retornan un JSON con un campo `error` y HTTP 500 (excepto
401 para fallas de autenticación, 404 para paths desconocidos).

## Thread safety

El servidor HTTP usa Indy con sus propios worker threads. Todas las
lecturas/escrituras RTTI e invocaciones de eventos son marshalled al main
thread del VCL vía `TThread.Synchronize`. Esto significa:

- Dumps RTTI pueden tardar si la app está ocupada en el main thread.
- Las invocaciones de eventos corren síncronamente desde la perspectiva del
  llamador.
- Eventos de larga duración bloquean la respuesta HTTP.
