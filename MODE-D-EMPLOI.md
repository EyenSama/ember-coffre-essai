# Mode d'emploi du banc d'essai

#type/note

Ce coffre sert à vérifier le déploiement, pas à écrire. Il ne contient aucune note personnelle.

## Voir les cinq teintes, sans rien déployer

Réglages → **Apparence** → tout en bas, **Extraits CSS** :

1. décoche `teinte-bleu` et coche `teinte-bordeaux` → tout le coffre change de teinte ;
2. recommence avec `teinte-vert-foret`, `teinte-violet`, `teinte-ambre`.

Un extrait = une teinte. C'est tout le principe : la mécanique dans `socle`, les couleurs dans la teinte.

## Ce qu'il y a à vérifier

- le thème **Border** est actif, et la teinte choisie colore l'accent, les surfaces et les halos ;
- les **dossiers** portent les couleurs de zones ;
- le texte des notes est **justifié**, les titres ont leur trait coloré ;
- le nom du fichier n'est **pas répété** au-dessus du titre ;
- les **onglets** affichent leur titre ;
- le greffon **Git** est présent et synchronise.

## Un point à observer

Obsidian active le **mode restreint** à la première ouverture d'un coffre. Regarde si les
greffons se chargent tout seuls — ou s'il faut un clic pour sortir du mode restreint.
