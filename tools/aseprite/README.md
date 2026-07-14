# Geradores para Aseprite

O script `generate_dungeon_tiles.lua` cria uma spritesheet 4×4 para o protótipo top-down:

- linha 1: quatro pisos (normal, rachado, detritos e musgo);
- linha 2: paredes nas quatro direções;
- linha 3: quatro cantos;
- linha 4: quatro variações de parede sólida.

## Instalação

1. No Aseprite, abra **File > Scripts > Open Scripts Folder**.
2. Copie `generate_dungeon_tiles.lua` para essa pasta.
3. Volte ao Aseprite e escolha **File > Scripts > Rescan Scripts Folder**.
4. Execute **File > Scripts > generate_dungeon_tiles**.

Use tile size `32` para o projeto atual. Depois de gerar, salve primeiro como `.aseprite` para manter o arquivo-fonte e exporte uma cópia `.png` para `sprites/tiles/dungeon_tiles_32px.png`.

No Godot, importe o PNG sem filtro, crie um `TileSet` com tamanho 32×32 e selecione as regiões da grade. As quatro primeiras células podem receber probabilidades diferentes para variar o piso sem alterar colisões.

O campo **Seed** reproduz exatamente as mesmas rachaduras, pedras e pontos de musgo.

## Personagens, armas e itens

O script `generate_game_assets.lua` possui três modos:

- **Character:** spritesheet 4×4. As linhas são baixo, esquerda, direita e cima; as colunas são os quatro quadros da caminhada.
- **Weapons:** quatro variações de espada, machado, arco e cajado.
- **Items:** quatro variações de poção, moeda, chave e baú.

Instale-o na mesma pasta de scripts e execute **File > Scripts > generate_game_assets**. Para o protótipo atual, use células de 32 px. Salve o arquivo-fonte `.aseprite` e exporte uma cópia PNG para uma subpasta de `sprites/`.

No Godot, configure o personagem com `hframes = 4` e `vframes = 4`. A ordem das animações é `down`, `left`, `right`, `up`, com quatro quadros em cada uma.
