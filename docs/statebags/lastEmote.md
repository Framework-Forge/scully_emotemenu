# lastEmote — Forge cache

Este caminho foi mantido para compatibilidade documental. A versão Forge não usa mais state bags para esta chave. Consulte o [guia de migração e exports](../FORGE_CACHE_MIGRATION.md).

Leitura no cliente:

```lua
local value = exports.scully_emotemenu:getEmoteState('lastEmote')
```

`lastEmote` permanece somente no cliente. O export existente `getLastEmote()` também retorna o emote e sua variação.
