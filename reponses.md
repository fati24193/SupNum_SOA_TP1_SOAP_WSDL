# TP1 — SOAP et WSDL · Partie A (Code-first)

**Étudiante :** fatimetou amar (24193) · SupNum — Architecture SOA & Web Services


> Projet : `emprunt-codefirst/` · Messages : `xml/` · WSDL généré : `xml/wsdl-genere-partieA.xml` · Tests : `tests-partieA.sh`
> Le serveur se lance avec `mvn compile exec:java` (dans `emprunt-codefirst/`).
> Numéros d'emprunt et dates : ils dépendent de l'ordre des appels et du jour d'exécution (ici le 24/11/2026, donc `dateRetour` = 2026-12-08).

---

## Étape 1 — Créer et lancer le service

**1. Annotations**
- `@WebService` (`jakarta.jws.WebService`) sur la classe `EmpruntService` en fait un service web. JAX-WS publie alors chaque méthode publique (`@WebMethod`) comme une opération. Il prend aussi `serviceName`, `portName` et `targetNamespace` pour générer `wsdl:service`, `wsdl:port` et l'espace de noms du contrat.
- `@WebFault` (`jakarta.xml.ws.WebFault`) sur `LivreIndisponibleException` en fait une erreur déclarée dans le contrat. Le WSDL contient alors un `wsdl:message` de fault, un `<wsdl:fault>` dans l'opération `emprunterLivre` (car la méthode a `throws LivreIndisponibleException`) et un élément XSD `LivreIndisponible` construit à partir de `getFaultInfo()`.

**2. Pourquoi un constructeur vide ?**
JAX-WS utilise JAXB pour convertir le XML en objets Java (et inversement). Pour désérialiser, JAXB **crée d'abord l'objet avec le constructeur sans argument**, puis remplit ses champs (`numero`, `dateRetour`…) par réflexion. Il ne sait pas quel constructeur avec paramètres appeler ni dans quel ordre. Sans constructeur vide, le service ne démarre pas : JAXB lève une `IllegalAnnotationsException` (*« does not have a no-arg default constructor »*).

---

## Étape 2 — Lire le WSDL généré

**1. URL et opérations**
- URL du service (dans `wsdl:service/wsdl:port/soap:address`) : `http://localhost:8080/bib/EmpruntService`

| Opération | Message d'entrée | Message de sortie | Fault |
|---|---|---|---|
| `emprunterLivre` | `emprunterLivre` → élément `tns:emprunterLivre` (`idAdherent`, `isbn`) | `emprunterLivreResponse` → élément `tns:emprunterLivreResponse` (`emprunt` : `numero`, `dateRetour`) | `LivreIndisponibleException` → élément `tns:LivreIndisponible` |
| `rendreLivre` | `rendreLivre` → élément `tns:rendreLivre` (`numeroEmprunt`) | `rendreLivreResponse` → élément `tns:rendreLivreResponse` (`penalite`) | — |

Chaque message n'a qu'un seul part nommé `parameters` (`fault` pour le message d'erreur), qui pointe vers un élément du schéma XSD importé depuis `?xsd=1`.

Le WSDL généré (Metro 4.0.2), lu de bas en haut :
- `service name="EmpruntService"` → `port name="EmpruntPort"` → `soap:address location="http://localhost:8080/bib/EmpruntService"`
- `binding name="EmpruntPortBinding" type="tns:EmpruntService"` : SOAP 1.1, `style="document"`, `soapAction=""`, `use="literal"`
- `portType name="EmpruntService"` (JAX-WS lui donne le nom de la classe) avec les opérations `rendreLivre` et `emprunterLivre`. Chaque input/output/fault porte un attribut `wsam:Action` (WS-Addressing), par exemple `http://supnum.mr/bib/EmpruntService/emprunterLivreRequest`, et `.../emprunterLivre/Fault/LivreIndisponibleException` pour la fault.
- `message` : `rendreLivre`, `rendreLivreResponse`, `emprunterLivre`, `emprunterLivreResponse`, `LivreIndisponibleException`
- `types` : un simple `xsd:import` de `http://localhost:8080/bib/EmpruntService?xsd=1`. Le schéma n'est pas recopié dans le WSDL.

**2. Style, use, version**
- On lit dans le binding `EmpruntPortBinding` : `<soap:binding style="document" .../>` et `<soap:body use="literal"/>`. C'est du **document/literal wrapped**. Le Body contient un élément enveloppe qui porte le nom de l'opération, et ses enfants sont les paramètres.
- C'est du **SOAP 1.1** : le binding utilise l'espace de noms `http://schemas.xmlsoap.org/wsdl/soap/` (et non `.../wsdl/soap12/`), avec `transport="http://schemas.xmlsoap.org/soap/http"`. Le `soapAction` des opérations est vide (`""`).

**3. Types XSD générés**
- `isbn` : `xs:string` (`minOccurs="0"`).
- `dateRetour` : `xs:string` aussi, car c'est un `String` en Java (ce n'est pas un `xs:date`).
- La règle de format de l'ISBN **n'apparaît pas** dans le contrat : il n'y a aucun `xs:pattern`. La regex se trouve seulement dans le code Java (`Pattern ISBN`). Un client qui lit le WSDL ne peut donc pas savoir quel format est attendu.

Extrait du schéma généré (`?xsd=1`, copié dans `xml/xsd-genere-partieA.xml`) :
```xml
<xs:complexType name="emprunterLivre">
  <xs:sequence>
    <xs:element name="idAdherent" type="xs:string" minOccurs="0"/>
    <xs:element name="isbn"       type="xs:string" minOccurs="0"/>
  </xs:sequence>
</xs:complexType>
<xs:complexType name="emprunt">
  <xs:sequence>
    <xs:element name="numero"     type="xs:string" minOccurs="0"/>
    <xs:element name="dateRetour" type="xs:string" minOccurs="0"/>
  </xs:sequence>
</xs:complexType>
```
Autres constats :
- Tous les éléments sont `minOccurs="0"` : JAX-WS déduit tout le schéma des types Java, et un `String` peut valoir `null`. Le contrat n'impose donc aucun champ obligatoire.
- `penalite` est en `xs:decimal` (car `BigDecimal` en Java).
- L'élément de fault `LivreIndisponible` est `nillable="true"`.
- Le schéma ne déclare pas `elementFormDefault` : les éléments locaux sont donc non qualifiés (voir la question 4).

**4. Préfixe sur les paramètres ?**
**Non.** Dans la requête SoapUI, seul l'élément de l'opération est qualifié (`<bib:emprunterLivre>`). Les paramètres `<idAdherent>` et `<isbn>` n'ont pas de préfixe : le schéma généré par JAX-WS ne déclare pas `elementFormDefault="qualified"`, donc les éléments locaux sont *unqualified* (sans espace de noms).

Résultat de l'envoi (A-117, 978-1-234-5678-9) : une réponse `emprunterLivreResponse` avec `<emprunt><numero>E-2026-0812</numero><dateRetour>2026-12-08</dateRetour></emprunt>`.

**5. HTTP, XML, SOAP et WSDL dans l'onglet Raw**
- **HTTP** : la ligne `POST /bib/EmpruntService HTTP/1.1` et les en-têtes (`Host`, `Content-Type: text/xml;charset=UTF-8`, `SOAPAction: ""`, `Content-Length`). HTTP est le **transport** : il achemine le message jusqu'à l'URL.
- **XML** : tout le corps de la requête. XML est le **format** : il apporte la syntaxe (balises, espaces de noms, encodage).
- **SOAP** : la structure `Envelope` / `Header` / `Body` (et `Fault`) dans ce XML. SOAP est le **protocole de messagerie** : il dit où placer les données métier, les en-têtes techniques (le jeton) et les erreurs.
- **WSDL** : il n'apparaît pas dans le message. C'est le **contrat** décrit à part : opérations, messages, types (XSD), binding (SOAP 1.1, document/literal) et adresse. SoapUI s'en sert pour générer la requête.

---

## Étape 3 — Envoyer des messages SOAP

Fichiers : `xml/01-emprunter.xml`, `xml/02-emprunter-12.xml`, `xml/04-rendre-errone.xml`, `xml/04-rendre-corrige.xml`.

Avec `01-emprunter.xml`, on obtient `HTTP/1.1 200 OK` et un `emprunterLivreResponse` qui contient un numéro (`E-2026-0813` si SoapUI a déjà pris le 0812) et `dateRetour` = 2026-12-08.

**1. Pourquoi POST, même pour lire ?**
SOAP utilise HTTP seulement comme un **tuyau de transport**. Le binding HTTP de SOAP 1.1 ne définit que POST. La requête est une enveloppe XML qui doit voyager dans le **corps** de la requête, et GET n'a pas de corps. De plus, toutes les opérations passent par **une seule URL** : l'opération est désignée par l'élément du Body (et le `SOAPAction`), pas par le verbe HTTP ni par l'URL. Le verbe ne dit donc rien de la sémantique (lecture ou écriture), contrairement à REST.

**2. Le jeton du Header a-t-il bloqué le traitement ?**
Non. Un bloc d'en-tête sans `mustUnderstand="1"` est **facultatif** : un destinataire qui ne le connaît pas a le droit de l'ignorer. Notre service ne déclare aucun handler pour `{http://supnum.mr/bib}jeton`, donc Metro l'ignore et traite le Body normalement.

**3. Réponse au message SOAP 1.2**
On obtient une Fault **VersionMismatch** (HTTP 500), renvoyée en SOAP 1.1 :
`faultcode = S:VersionMismatch`, `faultstring = "Couldn't create SOAP message. Expecting Envelope in namespace http://schemas.xmlsoap.org/soap/envelope/, but got http://www.w3.org/2003/05/soap-envelope"`.
Le binding lu à l'étape 2 est **SOAP 1.1** (`wsdl/soap/`), donc l'endpoint n'accepte que des enveloppes dans l'espace de noms 1.1. La version SOAP se reconnaît à l'espace de noms de l'`Envelope`. (De plus, un vrai message 1.2 serait envoyé en `Content-Type: application/soap+xml`, pas en `text/xml`.)

**4. Les cinq erreurs du message `rendreLivre`**

| # | Erreur | Correction | Réaction du serveur |
|---|---|---|---|
| 1 | `<soap:envelope>` en minuscule | `<soap:Envelope>` (XML est sensible à la casse) | Fault : élément racine `envelope` non reconnu comme enveloppe SOAP |
| 2 | `xmlns:bib="http://supnum.mr/bibliotheque"` | `xmlns:bib="http://supnum.mr/bib"` (targetNamespace du WSDL) | Fault Client : *Cannot find dispatch method for {http://supnum.mr/bibliotheque}rendreLivre* |
| 3 | `</rendreLivre>` ne ferme pas `<bib:rendreLivre>` | `</bib:rendreLivre>` | Fault : XML mal formé (*end tag mismatch*), refusé par le parseur (et par `xmllint`) |
| 4 | Paramètre `<bib:numero>` | `<numeroEmprunt>` : nom défini par `@WebParam`, **sans préfixe** (unqualified) | **Aucune erreur** : réponse 200 avec `penalite = 0` |
| 5 | `Header` placé **après** `Body` | `Header` doit être le premier enfant de `Envelope`, avant `Body` | **Aucune erreur** avec Metro : le jeton est simplement perdu |

Version corrigée : `xml/04-rendre-corrige.xml`.

**Erreurs silencieuses : 4 et 5.**
- **(4)** JAXB **ignore les éléments inconnus** (ici `{http://supnum.mr/bib}numero`) et rien n'impose que `numeroEmprunt` soit présent (`minOccurs="0"`, et pas de validation de schéma). Le paramètre arrive à `null` et, à cette étape, `rendreLivre` renvoie simplement 0. Le bug passe inaperçu. Après l'étape 4, il produit une Fault « Numéro d'emprunt inconnu : null ».
- **(5)** Metro lit l'enveloppe jusqu'au `Body` et ne vérifie pas strictement ce qui suit. Le Header mal placé n'est pas un bloc d'en-tête : il est ignoré, comme un jeton facultatif. Il n'y a pas de validation de la structure de l'enveloppe contre le schéma SOAP.

Le serveur ne détecte que ce qui l'empêche de **parser** (1, 3) ou de **router** (2) le message. Ce qui touche aux données passe sans contrôle, car le contrat code-first est permissif (tout `minOccurs="0"`, aucune validation).

---

## Étape 4 — Provoquer et construire des Faults

Fichiers : `xml/01a-isbn-mal-forme.xml`, `xml/01b-livre-indisponible.xml`, `xml/01c-mustunderstand-1.xml`, `xml/01d-mustunderstand-0.xml`, `xml/05-rendre-numero-invalide.xml`, `xml/03-fault-sender-12.xml`.

Le code de `rendreLivre` a été complété (Fault Client si le numéro ne commence pas par `E-2026-`). Avec `X-123`, on obtient une Fault `S:Client` / `Numéro d'emprunt inconnu : X-123` (HTTP 500).

`xmllint --noout xml/03-fault-sender-12.xml` ne renvoie aucune erreur : le fichier est bien formé.

**1. Cas 1 et 2**

| Cas | faultcode | faultstring | HTTP |
|---|---|---|---|
| 1 — ISBN `978-2-10` | `S:Client` | `ISBN mal formé : 978-2-10` | `500 Internal Server Error` |
| 2 — ISBN `978-2-10-074444-4` | `S:Server` | `Livre indisponible` | `500 Internal Server Error` |

En SOAP 1.1 sur HTTP, **toute Fault est renvoyée avec le code 500**, que la faute vienne du client ou du serveur.

**2. Contenu de `<detail>` (cas 2)**
```xml
<detail>
  <ns2:LivreIndisponible xmlns:ns2="http://supnum.mr/bib">
    <isbn>978-2-10-074444-4</isbn>
    <retourPrevu>2026-12-02</retourPrevu>
  </ns2:LivreIndisponible>
</detail>
```
C'est le `faultInfo` (`LivreIndisponibleInfo`) sérialisé par JAXB. Sa structure est décrite dans le WSDL :
`portType/operation emprunterLivre/<wsdl:fault name="LivreIndisponibleException">` → `wsdl:message LivreIndisponibleException` → `part element="tns:LivreIndisponible"` → dans le XSD (`?xsd=1`), l'élément `LivreIndisponible` de type `livreIndisponibleInfo` (`isbn`, `retourPrevu`). Le binding le relie par `<soap:fault name="LivreIndisponibleException" use="literal"/>`.

Le cas 1 n'a **pas** de detail : c'est une `SOAPFaultException` créée à la main, qui n'est pas déclarée dans le WSDL.

**3. Code choisi pour le livre indisponible**
JAX-WS a choisi **`Server`**, le code par défaut de toute exception métier `@WebFault`. Pourtant le serveur fonctionne correctement : la requête est valide et c'est une **règle métier** qui refuse l'emprunt. Selon la spécification, `Server` signifie « le message était correct, le traitement a échoué et pourrait réussir plus tard sans changement ». `Client` signifie « ne renvoyez pas ce message sans le modifier ».
**Mon choix : `Client` (`Sender` en 1.2).** Renvoyer la même requête donnera la même erreur jusqu'au 02/12. C'est donc au client de changer quelque chose (un autre livre, ou attendre). Avec `Server`, un client ou un intermédiaire pourrait croire à une panne et réessayer automatiquement pour rien.

**4. `mustUnderstand`**
- `mustUnderstand="1"` : le service **doit** comprendre ce bloc, sinon il doit refuser le message. Aucun handler ne gère `bib:jeton`, donc Metro renvoie une Fault **`S:MustUnderstand`** (HTTP 500) : *« MustUnderstand headers:[{http://supnum.mr/bib}jeton] are not understood »*. L'opération n'est **pas exécutée** (aucun emprunt créé).
- `mustUnderstand="0"` : c'est la valeur par défaut. Le bloc est facultatif, le service l'ignore et l'emprunt se fait normalement (200).

**5. Différences entre ma Fault 1.2 et les Faults 1.1 reçues**

| | SOAP 1.1 (reçues) | SOAP 1.2 (`03-fault-sender-12.xml`) |
|---|---|---|
| Espace de noms | `http://schemas.xmlsoap.org/soap/envelope/` | `http://www.w3.org/2003/05/soap-envelope` |
| Code | `<faultcode>S:Client</faultcode>` (texte simple) | `<soap:Code><soap:Value>soap:Sender</soap:Value></soap:Code>`, structuré, avec `soap:Subcode` possible |
| Valeurs | `Client` / `Server` | `Sender` / `Receiver` |
| Message | `<faultstring>` : un seul texte | `<soap:Reason><soap:Text xml:lang="fr">` : plusieurs langues possibles |
| Détail | `<detail>` non qualifié | `<soap:Detail>` qualifié |
| Enfants de Fault | non qualifiés (`faultcode`, `faultstring`…) | tous qualifiés (`soap:Code`, `soap:Reason`…), plus `soap:Node`/`soap:Role` facultatifs |
| HTTP | toujours 500 | **400** pour `Sender`, 500 pour `Receiver`, `Content-Type: application/soap+xml` |

---

## Résultats obtenus sur notre machine (tests-partieA.sh, 24/11/2026)

**1er lancement (serveur qui vient de démarrer)**

| Message | Résultat obtenu | Conforme ? |
|---|---|---|
| `01-emprunter.xml` | `HTTP/1.1 200 OK`, `numero = E-2026-0812`, `dateRetour = 2026-12-08` | Oui |
| `02-emprunter-12.xml` (SOAP 1.2) | `curl: (52) Empty reply from server` | Message refusé (version SOAP non supportée, voir étape 3 Q3) |
| `04-rendre-errone.xml` | `curl: (52) Empty reply from server` | Message refusé (XML mal formé, voir étape 3 Q4) |
| `04-rendre-corrige.xml` | `HTTP/1.1 200 OK`, `penalite = 0` | Oui |
| `01a-isbn-mal-forme.xml` | `HTTP/1.1 500 Internal Server Error` | Oui (Fault Client) |
| `01b-livre-indisponible.xml` | `HTTP/1.1 500 Internal Server Error` | Oui (Fault Server) |
| `01c-mustunderstand-1.xml` | `HTTP/1.1 500 Internal Server Error` | Oui (MustUnderstand) |
| `05-rendre-numero-invalide.xml` | `HTTP/1.1 500 Internal Server Error` | Oui (Fault Client) |

**2e lancement (sans redémarrer le serveur)**

| Message | Résultat obtenu | Explication |
|---|---|---|
| `01-emprunter.xml` | `HTTP/1.1 500` | Le livre `978-2-07-036822-8` a été emprunté au 1er lancement et le service garde cet état en mémoire (map `sortis`) : on obtient donc la Fault « Livre indisponible ». |
| `01d-mustunderstand-0.xml` | `HTTP/1.1 200 OK`, `numero = E-2026-0813`, `dateRetour = 2026-12-08` | Oui : avec `mustUnderstand="0"`, le jeton est ignoré et l'emprunt se fait. Le compteur continue (0812 → 0813). |
| Autres messages | Identiques au 1er lancement | — |

**Remarques :**
- Toutes les Faults SOAP 1.1 arrivent avec le code **HTTP 500**, comme prévu (étape 4 Q1). Sur notre poste (Windows, Git Bash), le corps de ces réponses est arrivé vide. Le contenu attendu (`faultcode`, `faultstring`, `detail`) est décrit à l'étape 4.
- Pour SOAP 1.2 et le message mal formé, le serveur ferme la connexion sans aucune réponse HTTP (`Empty reply from server`) : le message est refusé avant d'atteindre le service.
- `xmllint` n'étant pas installé sous Windows, nous avons vérifié `03-fault-sender-12.xml` en l'ouvrant dans le navigateur (le document s'affiche sous forme d'arbre, donc il est bien formé).
