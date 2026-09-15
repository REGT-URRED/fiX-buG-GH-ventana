# fiX-buG-GH-ventana

Solucionador para Windows que restaura el **selector de cuentas de Git Credential Manager (GCM)** cuando no aparece al hacer `git clone` o `git push`, y permite **limpiar cuentas guardadas de forma selectiva**.

## Problemas que resuelve

### 1) No aparece la ventana de inicio de sesión

**Síntoma:** al clonar o empujar un repositorio, Git falla con error de autenticación (o se queda esperando) y no aparece la ventana de cuentas.

**Causa:** la configuración de Git tiene un *override* que apunta a `gh.exe` (GitHub CLI):

```
credential.https://github.com.helper = !gh auth git-credential
```

Ese override hace que Git use `gh` en lugar del selector interactivo de GCM, y la ventana nunca aparece.

### 2) Aparecen cuentas que no corresponden

**Síntoma:** el selector lista usuarios de más. Por ejemplo `oauth2` o `x-access-token`.

**Causa:** quedaron credenciales huérfanas en el Administrador de credenciales de Windows, típicamente de clones hechos con un token embebido en la URL o con tokens de GitHub App. GCM las lista como si fueran cuentas.

## Requisitos

- Windows 10 / 11
- [Git for Windows](https://git-scm.com/download/win) instalado
- Git Credential Manager (viene incluido con Git for Windows; si falta: `winget install Git.CredentialManager`)

No requiere permisos de administrador.

## Uso

1. Descarga `fix-github-credential.bat`
2. Haz doble clic (o ejecútalo desde cmd)

Aparece un menú. No hay que editar el archivo ni configurar nada.

## Menú

| Opción | Qué hace |
| ------ | -------- |
| `1) Corregir` | Elimina los overrides de `gh.exe` (global y local) y asegura `credential.helper=manager`. No toca cuentas. |
| `2) Verificar` | Muestra las cuentas de GCM, las entradas del Administrador de credenciales de Windows, y valida cada token contra la API. **No modifica nada.** |
| `3) Limpiar` | Lista las cuentas numeradas y permite elegir cuáles eliminar o conservar. |
| `4) Otros` | Reparar / actualizar tokens vencidos, o ver la solución manual. |
| `0) Salir` | Cierra el programa. |

### Detalle de `3) Limpiar`

Primero lista las cuentas detectadas con un número:

```
Cuentas detectadas en GCM:
    1) usuario-uno
    2) usuario-dos
    3) oauth2

  a) Eliminar las que elija    (el resto se conserva)
  b) Conservar las que elija   (el resto se elimina)
  v) Volver
```

Después se eligen los números:

- `1 3` o `1,3` → esas dos cuentas
- `*` → todas

**Antes de borrar nada** muestra exactamente qué se va a eliminar y qué se conserva, y pide confirmación `S/N`. Si no confirmás, no toca nada.

El borrado solo afecta a las cuentas seleccionadas. No toca credenciales de otros hosts (`gist.github.com`, GitLab, etc.) ni la configuración de Git.

## Códigos de salida

| Código | Significado |
| ------ | ----------- |
| 0 | Terminó normalmente |
| 1 | `git` no encontrado en el sistema |

## Privacidad

- El script **no contiene** cuentas, tokens ni rutas de usuario. Las cuentas se detectan y se eligen desde el menú.
- **No lee, guarda ni transmite credenciales**, con una excepción: la opción `4) Otros → a) Reparar tokens`, que pide un PAT nuevo y lo guarda en GCM. Eso solo ocurre si vos lo elegís.
- Los archivos temporales que crea se eliminan inmediatamente.
- La validación de tokens (opción `2) Verificar`) consulta `api.github.com/user` con el token ya guardado, únicamente para leer el código HTTP de respuesta.

## Solución manual

Si preferís no ejecutar el `.bat`, estos comandos hacen lo mismo:

```bat
git config --global --unset-all credential.https://github.com.helper
git config --global --unset-all credential.https://gist.github.com.helper
git config --local  --unset-all credential.https://github.com.helper
git config --local  --unset-all credential.https://gist.github.com.helper
git config --global credential.helper manager
```

Para ver qué hay guardado:

```bat
git credential-manager github list
cmdkey /list
```

Para eliminar una cuenta puntual:

```bat
git credential-manager github logout <usuario>
```

## Licencia

Uso libre.
