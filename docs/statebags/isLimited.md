# isLimited — Forge cache

Este caminho foi mantido para compatibilidade documental. A versão Forge não usa mais state bags para esta chave. Consulte o [guia de migração e exports](../FORGE_CACHE_MIGRATION.md).

Leitura no cliente:

```lua
local value = exports.scully_emotemenu:getEmoteState('isLimited')
```

Leitura no servidor:

```lua
local state = exports.scully_emotemenu:getPlayerEmoteState(source)
local value = state and state.isLimited
```

Use `setLimitation(boolean)` no cliente ou `setPlayerLimitation(source, boolean)` no servidor.
