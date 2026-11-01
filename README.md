# Giant Back Tycoon

Tycoon de Roblox en el que tu base está construida sobre la espalda de un gigante que caminas, alimentas y crías. Diseño completo en [docs/GDD.md](docs/GDD.md); instrucciones para Claude Code en [CLAUDE.md](CLAUDE.md).

## Puesta en marcha

1. Instala [Rokit](https://github.com/rojo-rbx/rokit) y, en la raíz del repositorio, las herramientas:

   ```bash
   rokit install
   ```

2. Descarga los paquetes (ProfileStore):

   ```bash
   wally install
   ```

3. Instala el plugin de Rojo en Roblox Studio (`rojo plugin install`) y arranca el servidor de sincronización:

   ```bash
   rojo serve
   ```

4. En Studio, abre una place vacía, pulsa **Rojo → Connect** y después **Play**.

## Comprobaciones de código

```bash
stylua --check src
```

```bash
selene src
```

## Estructura

```text
src/server/services     → ServerScriptService.Server.services   (lógica autoritativa)
src/client/controllers  → StarterPlayerScripts.Client.controllers (presentación y entrada)
src/shared              → ReplicatedStorage.Shared              (Config, tipos, fórmulas, remotos)
assets                  → ReplicatedStorage.Assets              (modelos .rbxm)
```

## Estado

| Hito | Estado |
| --- | --- |
| M0. Proyecto base | Comprobado en Studio |
| M1. El gigante que camina | — |
