# Décisions de conception

1. **Source** : jeu ist-daten-v2 via l'API CKAN d'opendata.swiss, fenêtre glissante de 50 jours.

2. **Couche brute** : tout en VARCHAR, car l'inférence de schéma cassait à la ligne 76 905 sur LINIEN_ID.

3. **Normalisation** de PRODUKT_ID (Bus / BUS).

4. **Retard** calculé uniquement sur les heures REAL (88 % des arrivées).

5. **Ponctualité** : retard de moins de 3 minutes ; retard brut conservé, retard_positif utilisé pour les moyennes.

6. **Filtrage** sur les identifiants (BPUIC), pas sur les noms de gares.

7. **Langues** : renommage des colonnes et traduction des valeurs en anglais dans la couche staging ; la couche brute conserve les noms allemands d'origine.
