# TP1 SOAP et WSDL : Partie B (Contract-first)

## Étape 5 : Générer le code depuis le WSDL

**1. Dans ce WSDL, retrouvez l'opération, son message de fault et l'action SOAP à envoyer.**

- Opération : `emprunterLivre` (dans le `portType` `EmpruntPortType`).
- Message de fault : `LivreIndisponibleFault`, déclaré par `<wsdl:fault name="LivreIndisponible" message="bib:LivreIndisponibleFault"/>`. Il porte l'élément `bib:LivreIndisponible`.
- Action SOAP : `http://supnum.mr/bib/emprunterLivre`, définie dans `<soap:operation soapAction="..."/>` du binding.

**2. Quelle est la signature de `emprunterLivre` dans `EmpruntPortType` ?**

```java
EmpruntType emprunterLivre(String idAdherent, String isbn) throws LivreIndisponibleFault
```

Le style document/literal « wrapped » permet à `wsimport` de transformer les enfants de l'élément `emprunterLivre` (`idAdherent`, `isbn`) en paramètres Java, et l'élément `emprunt` de la réponse en valeur de retour.

**3. Quel type Java a été généré pour `dateRetour` ? Comparez avec la partie A.**

- Partie B : `javax.xml.datatype.XMLGregorianCalendar`, car le schéma déclare `xs:date`.
- Partie A : `String`, donc `xs:string` dans le WSDL généré.

Le contrat de la partie B est donc plus précis : le type de la date est vérifiable par le schéma.

**4. Quel est le nom de la classe d'exception générée, et d'où vient ce nom dans le WSDL ?**

La classe s'appelle `LivreIndisponibleFault`. Son nom vient du `wsdl:message name="LivreIndisponibleFault"`. L'élément `LivreIndisponible` (le contenu du detail) devient une classe séparée, `LivreIndisponible`, utilisée comme `faultInfo` de l'exception.

## Étape 6 : Implémenter et comparer

**1. Le WSDL publié est-il celui que vous avez fourni ? Contient-il le motif de l'ISBN et le type `xs:date` ?**

Oui. Grâce à `wsdlLocation` dans l'annotation `@WebService`, Metro publie le WSDL fourni (seule l'adresse `soap:address` peut être adaptée). Il contient bien le motif de l'ISBN (`xs:pattern` dans `IsbnType`) et les champs de type `xs:date`.

**2. Avez-vous dû modifier `01-emprunter.xml` pour qu'il fonctionne ici ? Pourquoi ?**

Oui, deux choses changent :

- Les enfants de `emprunterLivre` doivent avoir le préfixe `bib:` (`<bib:idAdherent>`, `<bib:isbn>`). Le schéma déclare `elementFormDefault="qualified"`, donc les éléments doivent appartenir à l'espace de noms `http://supnum.mr/bib`. En partie A, ils n'avaient pas de préfixe (non qualifiés).
- Le header HTTP `SOAPAction` passe de `""` à `"http://supnum.mr/bib/emprunterLivre"`, valeur déclarée dans le binding.

**3. Sans `@SchemaValidation`, l'ISBN `978-2-10` est-il refusé ? Et avec ? Quelle Fault obtenez-vous ?**

- Sans `@SchemaValidation` : non, il n'est pas refusé. Metro ne valide pas les messages par défaut et le code de l'implémentation ne vérifie pas le format. Le service répond HTTP 200 avec un emprunt.
- Avec `@SchemaValidation` : il est refusé avant d'atteindre le code. La réponse est une Fault SOAP 1.1 de code `Client` (faultcode de type `S:Client`), avec un `faultstring` indiquant une erreur de validation (`cvc-pattern-valid`, la valeur n'est pas conforme au motif de `IsbnType`), et un statut HTTP 500.

*(Recopier ici le faultstring exact obtenu lors du test.)*

**4. Retirez `wsdlLocation` de l'annotation et redémarrez : qu'est-ce qui change dans le WSDL publié ?**

Metro génère alors le WSDL à partir des annotations et de l'interface, comme en partie A, au lieu de publier le fichier fourni. Le WSDL publié change : le schéma est déplacé dans un XSD séparé (`?xsd=1`), le motif de l'ISBN disparaît (`isbn` redevient `xs:string`), et les noms et la structure sont ceux produits par Metro et non ceux du contrat d'origine.

## Conclusion : Choisir et rendre

**1. Citez deux différences que vous avez observées entre le WSDL de la partie A et celui de la partie B.**

1. Types et contraintes : en A, `dateRetour` et `isbn` sont des `xs:string`, sans motif ; en B, `dateRetour` est un `xs:date` et `isbn` utilise `IsbnType` avec un `xs:pattern`.
2. Structure : en A, le WSDL est découpé (le schéma est dans un XSD séparé importé via `?xsd=1`), le `soapAction` est vide et les éléments des paramètres ne sont pas qualifiés ; en B, le schéma est inline, le `soapAction` est explicite et les éléments sont qualifiés.

**2. Si on renomme le champ `dateRetour` dans le code, quel projet voit son contrat changer ? Quel risque pour les clients ?**

Le projet A (code-first) : le WSDL est généré à partir du code, donc le renommage modifie automatiquement le contrat. En B, le WSDL est la source et reste inchangé ; le renommage dans le code casserait la compilation, ce qui rend la dérive visible.

Risque pour les clients : changement incompatible silencieux. Les clients qui envoient ou attendent l'ancien nom de champ échouent ou voient le champ ignoré, et leurs classes générées à partir de l'ancien WSDL deviennent obsolètes.

**3. Quelle approche choisiriez-vous pour le service Paiement, appelé par Scolarité (.NET), Bibliothèque (PHP) et le portail (Node.js) ? Et pour un prototype interne de deux jours ?**

- Service Paiement : **contract-first**. Plusieurs équipes et plusieurs langages partagent le contrat. Le WSDL sert de référence commune, stable et versionnable, et chaque équipe génère son client dans son langage.
- Prototype interne de deux jours : **code-first**. C'est plus rapide à écrire, avec un seul consommateur, à condition de figer le WSDL avant toute mise en production.
