# DelphiTestAgent HTTP Protocol

The agent exposes a small REST-like HTTP API on `127.0.0.1:8765` (configurable).
All responses are `application/json; charset=utf-8`. Authentication is optional
via the `X-Agent-Token` header.

## Endpoints

### GET /health
Liveness probe.

Response:
```
{"status":"ok","agent":"DelphiTestAgent","version":"0.1.0"}
```

### GET /tree
Full component tree of all forms visible in `Screen.Forms`. Recursive up to
`Config.MaxDepth` (default 20).

Response shape:
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
Flat list of Name:ClassName for quick discovery.

Response:
```
{"components":["FormMain:TFormMain","btnCalcular:TButton",...]}
```

### GET /dump/:name
Dump a single component subtree by Name.

### GET /get/:component/:property
Read a published property via `TypInfo.GetPropValue`.

Response on success:
```
{"component":"edNome","property":"Text","value":"Joao"}
```

On error:
```
{"component":"edNome","property":"Text","error":"..."}
```

### POST /set
Set a published property via `TypInfo.SetPropValue`. Accepts strings; the RTTI
conversion handles integers, enums, booleans, etc.

Body:
```
{"component":"edNome","property":"Text","value":"Joao"}
```

Response:
```
{"component":"edNome","property":"Text","value":"Joao","status":"ok"}
```

### POST /click
Invoke `OnClick` of the named component via `TypInfo.GetMethodProp`. Runs on
the main thread via `TThread.Synchronize`.

Body: `{"component":"btnCalcular"}`
Response: `{"component":"btnCalcular","event":"OnClick","status":"invoked"}`

### POST /invoke
Invoke any `TNotifyEvent` published on the component.

Body: `{"component":"edValor","event":"OnExit"}`

### POST /focus
Call `SetFocus` on the component if it descends from `TWinControl`.

Body: `{"component":"edNome"}`

### POST /sendkey
Post a `WM_KEYDOWN`/`WM_KEYUP` pair to the focused window. Accepts:
- Single character: `"A"`, `"5"`
- VK names: `VK_RETURN`, `VK_TAB`, `VK_ESCAPE`, `VK_SPACE`, `VK_F1`..`VK_F6`,
  `VK_UP`, `VK_DOWN`, `VK_LEFT`, `VK_RIGHT`

Body: `{"key":"VK_RETURN"}`

## Authentication

If `Config.Token` is set, every request must include
`X-Agent-Token: <token>` header. Requests without the token return HTTP 401.

## Errors

All errors return a JSON body with an `error` field and HTTP 500 (except 401
for auth failures, 404 for unknown paths).

## Thread safety

The HTTP server uses Indy with its own worker threads. All RTTI reads /
writes and event invocations are marshalled to the main VCL thread via
`TThread.Synchronize`. This means:
- RTTI dumps can take a long time if the app is busy on the main thread.
- Event invocations will run synchronously from the caller's POV.
- Long-running events will block the HTTP response.
