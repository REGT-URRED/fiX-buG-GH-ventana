# fiX-buG-GH-ventana

Solucionador para Windows que restaura el **selector de cuentas de Git Credential Manager (GCM)** cuando no aparece al hacer `git clone` o `git push` en repositorios de GitHub.

## Problema que resuelve

**Síntoma:** al clonar o empujar un repositorio, Git falla con error de autenticación (o se queda esperando) y **no aparece la ventana de inicio de sesión**.

**Causa:** la configuración de Git tiene un *override* que apunta a `gh.exe` (GitHub CLI) para `github.com` y `gist.github.com`:

```
credential.https://github.com.helper = !gh auth git-credential
```

Ese override hace que Git use `gh` en lugar del selector interactivo de GCM, y la ventana de cuentas nunca aparece.

## Requisitos

- Windows 10 / 11
- [Git for Windows](https://git-scm.com/download/win) instalado
- Git Credential Manager (viene incluido con Git for Windows; si falta, se instala con `winget install Git.CredentialManager`)

No requiere permisos de administrador.

## Uso

1. Descarga `fix-github-credential.bat`
2. Haz doble clic (o ejecútalo desde cmd)

El script **verifica primero y solo corrige si hace falta**: si todo funciona, termina sin tocar nada.

## Qué hace el script

1. Verifica que `git` esté instalado.
2. Detecta overrides de `gh.exe` en la configuración global y local.
3. Prueba si GCM responde (`git credential fill`).
4. Solo si hay un problema:
   - Elimina los overrides de `gh.exe` (global y local)
   - Asegura `credential.helper=manager`
   - Re-verifica que GCM responde

## Códigos de salida

| Código | Significado |
| ------ | ----------- |
| 0      | Todo correcto, o solución aplicada con éxito |
| 1      | `git` no encontrado en el sistema |
| 2      | GCM sigue sin responder (posiblemente no instalado) |

## Solución manual (equivalente)

Si prefieres no ejecutar el .bat, estos comandos hacen lo mismo:

```bat
git config --global --unset-all credential.https://github.com.helper
git config --global --unset-all credential.https://gist.github.com.helper
git config --local  --unset-all credential.https://github.com.helper
git config --local  --unset-all credential.https://gist.github.com.helper
git config --global credential.helper manager
```

## Privacidad

El script **no lee, guarda ni transmite credenciales**. Solo modifica las claves de configuración de Git indicadas arriba. Los archivos temporales que crea (para la prueba `credential fill`) se eliminan inmediatamente.

## Licencia

Uso libre.
