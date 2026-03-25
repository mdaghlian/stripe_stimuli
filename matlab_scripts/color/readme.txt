

## Note on randomisation in colourProject.m 

- A condition is an orientation+stim combination
- e.g., bw-0deg; bw-90deg; colour-0deg; etc. 
- 2xstim (bw; colour)
- 4xorientation (0 45 90 135)
- so 8 conditions in total
- ***
- Each condition in 1:nConditions (8) appears exactly nBlocks/nConditions
- if we set 8 blocks, then that is once per run
- ***
- the list of 8-conditions is shuffled randomly
- -> then checked that:
- -> (1) No 2 consecutive blocks can be the same condition
- -> (2) No 3 consecutive blocks can be the same stim type (bw; colour)
- ***
- this list is then doubled [a,b,c] -> [a,a,b,b,c,c]
- Giving even & odd block IDs; motion direction is flipped 
- Across runs - the same blocks always have the same stim 
- but orientation can change

