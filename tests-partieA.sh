#!/usr/bin/env bash
# Tests de la partie A — lancer le serveur avant : cd emprunt-codefirst && mvn compile exec:java
URL=http://localhost:8080/bib/EmpruntService
envoyer() {
  echo; echo "===== $1 ====="
  curl -sS -i -X POST "$URL" -H 'Content-Type: text/xml; charset=utf-8' -H 'SOAPAction: ""' \
       --data-binary @"xml/$1"
  echo
}
envoyer 01-emprunter.xml               # Étape 3.2 : 200 + emprunterLivreResponse
envoyer 02-emprunter-12.xml            # Étape 3.3 : Fault VersionMismatch
envoyer 04-rendre-errone.xml           # Étape 3.4 : message avec 5 erreurs
envoyer 04-rendre-corrige.xml          # Étape 3.4 : version corrigée
envoyer 01a-isbn-mal-forme.xml         # Étape 4.1 : Fault Client
envoyer 01b-livre-indisponible.xml     # Étape 4.2 : Fault Server + detail
envoyer 01c-mustunderstand-1.xml       # Étape 4.3 : Fault MustUnderstand
envoyer 01d-mustunderstand-0.xml       # Étape 4.3 : traitement normal
envoyer 05-rendre-numero-invalide.xml  # Étape 4.4 : Fault Client (rendreLivre)
echo
if command -v xmllint >/dev/null; then xmllint --noout xml/03-fault-sender-12.xml && echo "03-fault-sender-12.xml : OK"; else echo "xmllint absent : vérifier 03-fault-sender-12.xml en l ouvrant dans le navigateur"; fi
