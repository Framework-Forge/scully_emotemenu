# Scully Emote Menu — cache Forge

Implementado em 01/10/2026. **Homologação no FiveM pendente.** Nenhum outro recurso de runtime foi alterado nesta conversão.

## Estrutura

- Estado temporário em `pr_lib.cache`, namespace `scully_emotemenu:`. `PlayerState` agora é uma fachada de cache, não `LocalPlayer.state`.
- As escritas por propriedade e por `:set(key, value, replicate)` mantêm o formato interno, mas o terceiro argumento indica envio pelo transporte próprio; não é TTL de cache.
- `lastEmote` e `emoteCooldown` ficam somente no cliente. Props, partículas, caminhada, expressão, postura, mãos levantadas e flags de emote usam o contrato público validado.
- Escritas agrupadas pelo cliente; callbacks `scully_emotemenu:publishState` e `scully_emotemenu:getStateSnapshot` registrados no PR Bridge. Deltas são enviados pelo servidor em eventos do recurso para observadores cadastrados, nunca por broadcast global.
- O servidor valida tamanho, tipos, transformações, distância de até 200 metros e routing bucket. Ele identifica o produtor pela origem real do callback, não por um ID fornecido pelo cliente.
- Clientes consultam os jogadores em streaming uma vez por segundo. Snapshots quando a lista muda e revalidação a cada cinco segundos recuperam entrada tardia/aproximação. Não se trata de uma nova varredura global de entidades no servidor.
- Props/partículas são locais para cada observador. Há revisão de estado, comparação estrutural para evitar duplicação, invalidação durante carregamentos, limpeza por stream-out, disconnect, troca do ped e restart do recurso.
- Postura observa apenas o cache local; não aplica mais alterações de postura de outro jogador ao próprio ped.
- Corrigida a limpeza da coleção de props e a resolução do osso VFX do objeto. Efeitos sem escala informada usam `1.0`.
- Sintaxe estendida e hashes literais convertidos a Lua padrão/`joaat`, preservando os valores, para permitir validação direta com luac.

## Exports para integrações

### Cliente

```lua
local state = exports.scully_emotemenu:getEmoteState('isInEmote')
local handsup = exports.scully_emotemenu:getEmoteState('handsup')
local walk = exports.scully_emotemenu:getEmoteState('walkstyle')
exports.scully_emotemenu:setEmoteStance(2) -- 0 normal; 1 furtivo; 2 agachado
exports.scully_emotemenu:setEmoteStance(0)
exports.scully_emotemenu:setAllowNSFWEmotes(true) -- controle local da integração
exports.scully_emotemenu:setLimitation(true) -- export existente preservado
```

### Servidor

```lua
local state = exports.scully_emotemenu:getPlayerEmoteState(source)
local inEmote = state and state.isInEmote
exports.scully_emotemenu:setPlayerLimitation(source, true)
exports.scully_emotemenu:setPlayerAllowNSFWEmotes(source, true)
```

O getter do servidor devolve cópia do estado público, ou `nil` se não houver registro. `lastEmote` não é replicado. A permissão NSFW não é aceita nos batches de rede enviados pelo jogador; integrações de servidor usam o export correspondente. Controles de interface cliente não substituem autorização de gameplay no servidor.

Integrações antigas que consultavam/escreviam state bags devem passar aos exports acima. Os exports existentes de emotes, caminhada, expressão e limitação continuam disponíveis. O handshake de emotes sincronizados existente foi preservado; esta etapa não certifica segurança integral desse protocolo legado.

## Verificação

- `lua55.exe tests/cache_state_test.lua`: fachada, campos privados, payloads inválidos, snapshots, destinatários, distância/bucket, revisão, streaming, desconexão e controles de servidor.
- Catálogo validado: 597 emotes com props e 46 com partículas compatíveis com o contrato.
- `luac55.exe -p`: 31 arquivos Lua aprovados, incluindo fontes, módulos, manifest e teste; não depende de parser de sintaxe FiveM estendida.
- Varredura: nenhum acesso direto a state bags nos arquivos Lua.

Estes são testes estáticos/isolados; desempenho sob carga e funcionamento com jogadores ainda precisam de homologação.

## Teste no FiveM

1. Reiniciar `scully_emotemenu`; abrir menu e executar/cancelar emote simples, cenário e emote com props.
2. Com dois jogadores, testar props e partículas (ex.: champagne spray), ativação/encerramento e ausência de duplicatas ao repetir.
3. Testar emote sincronizado: aceitar, cancelar de ambos os lados e desconectar um participante.
4. Testar agachado/furtivo, mãos levantadas, apontar, ragdoll, caminhada e expressão. A postura de um jogador não deve alterar a do outro.
5. Aproximar-se de alguém já em emote, afastar-se e voltar; trocar routing bucket. Conferir reidratação e limpeza dos efeitos.
6. Testar morte, troca de ped e restart sem objetos/efeitos órfãos; testar exports de limitação e NSFW se usados pela base.

Atualizar o plano do PR Bridge para aprovado somente após confirmação do responsável.
