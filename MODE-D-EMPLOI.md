# Mode d'emploi du banc d'essai

#type/note

Ce coffre sert à vérifier le déploiement, pas à écrire. Il ne contient aucune note personnelle.

## Voir les douze teintes, sans rien déployer

Réglages → **Apparence** → tout en bas, **Extraits CSS**. Décoche une teinte, coche-en une autre :
tout le coffre change de couleur. Les familles disponibles :

- **bleus** : `bleu` · `bleu-ocean` · `ciel-azur` · `ardoise`
- **verts** : `vert-foret` · `emeraude` · `sauge`
- **rouges et violets** : `bordeaux` · `prune` · `rose-poudre` · `violet`
- **chaud** : `ambre`

Un extrait = une teinte. C'est tout le principe : la mécanique dans `socle`, les couleurs dans la teinte.

## Ce qu'il y a à vérifier

- le thème **Border** est actif, et la teinte choisie colore l'accent, les surfaces et les halos ;
- les **dossiers** portent les couleurs de zones, une par dossier ;
- le texte des notes est **justifié**, les titres ont leur trait coloré ;
- le nom du fichier n'est **pas répété** au-dessus du titre ;
- les **onglets** affichent leur titre ;
- le greffon **Git** est présent et synchronise.

## Un point à observer

Obsidian active le **mode restreint** à la première ouverture d'un coffre. Regarde si les
greffons se chargent tout seuls — ou s'il faut un clic pour sortir du mode restreint.
