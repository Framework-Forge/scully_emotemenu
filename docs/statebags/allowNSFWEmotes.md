# allowNSFWEmotes — Forge cache

Este caminho foi mantido para compatibilidade documental. A versão Forge não usa mais state bags para esta chave. Consulte o [guia de migração e exports](../FORGE_CACHE_MIGRATION.md).

Leitura no cliente:

```lua
local value = exports.scully_emotemenu:getEmoteState('allowNSFWEmotes')
```

Leitura no servidor:

```lua
local state = exports.scully_emotemenu:getPlayerEmoteState(source)
local value = state and state.allowNSFWEmotes
```

Para modo limitado, controle pelo servidor:

```lua
exports.scully_emotemenu:setPlayerAllowNSFWEmotes(source, true)
exports.scully_emotemenu:setPlayerAllowNSFWEmotes(source, false)
```

Integrações locais podem usar `setAllowNSFWEmotes(boolean)`; isso não substitui autorização de gameplay no servidor.
