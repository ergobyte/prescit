#!/bin/bash
#
#	Copyright 2023 Ergobyte Informatics S.A.
#
#	Licensed under the Apache License, Version 2.0 (the "License");
#	you may not use this file except in compliance with the License.
#	You may obtain a copy of the License at
#
#	    http://www.apache.org/licenses/LICENSE-2.0
#
#	Unless required by applicable law or agreed to in writing, software
#	distributed under the License is distributed on an "AS IS" BASIS,
#	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#	See the License for the specific language governing permissions and
#	limitations under the License.
#

SERVER='https://ehealth-services.inab.certh.gr/sparql'
USERNAME=''
PASSWORD=''

case $1 in
	openPvSignal)
		read -r -d '' QUERY <<-EOF
			PREFIX pvs: <http://purl.org/OpenPVSignal/OpenPVSignal.owl#>
			PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			PREFIX obo: <http://purl.obolibrary.org/obo/>
			SELECT ?drug, ?atc, ?adr, ?meddra, ?con
			FROM <https://raw.githubusercontent.com/achillec/OpenPVSignal/master/OpenPVSignal.ttl>
			WHERE { 
				?x	a pvs:Warning_Information .
				?x	pvs:refers_to_secondary_suspect_drug | pvs:refers_to_primary_suspect_drug | pvs:refers_to_drug | pvs:refers_to_class ?y .
				?x	pvs:has_content ?con .
				?x	pvs:refers_to_adverse_effect ?z .
				?y	pvs:has_ATC_code ?atc .
				?y	rdfs:label ?drug .
				?z	pvs:has_MedDRA_code ?meddra .
				?z	pvs:has_MedDRA_code '10029331'^^xsd:integer .
				?z	rdfs:label ?adr .
			}
		EOF
		read -r -d '' JQE <<-EOF
			.results.bindings[]
			| {
				"drug": .drug.value,
				"atc": .atc.value,
				"drug": .drug.value,
				"meddra": .meddra.value,
				"con": .con.value
			}
		EOF
		;;
	drugBankIds)
		read -r -d '' QUERY <<-EOF
			PREFIX : <http://semmeddbeh/metathesaurus#>
			PREFIX owl: <http://www.w3.org/2002/07/owl#>
			PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			SELECT ?atc, ?db, ?title WHERE {
				?x a owl:NamedIndividual .
				?x :ATC ?atc .
				?x :DRUGBANK ?db .
				?x rdfs:label ?title .
			}
		EOF
		read -r -d '' JQE <<-EOF
			.results.bindings[]
			| {
				"atc": .atc.value,
				"db": .db.value,
				"title": .title.value
			}
		EOF
		;;
	meddraCodes)
		read -r -d '' QUERY <<-EOF
			PREFIX : <http://semmeddbeh/metathesaurus#>
			PREFIX owl: <http://www.w3.org/2002/07/owl#>
			PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			SELECT DISTINCT ?code, ?title WHERE {
				?x a owl:NamedIndividual .
				?x :MDR	?code .
				?x rdfs:label ?title .
			}
		EOF
		read -r -d '' JQE <<-EOF
			.results.bindings[]
			| {
				"code": .code.value,
				"title": .title.value
			}
		EOF
		;;
	rxNormIds)
		read -r -d '' QUERY <<-EOF
			PREFIX : <http://semmeddbeh/metathesaurus#>
			PREFIX owl: <http://www.w3.org/2002/07/owl#>
			PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			SELECT DISTINCT ?atc, ?rx, ?title WHERE {
				?x a owl:NamedIndividual .
				?x :ATC ?atc .
				?x :RXNORM ?rx .
				?x rdfs:label ?title .
			}
		EOF
		read -r -d '' JQE <<-EOF
			.results.bindings[]
			| {
				"atc": .atc.value,
				"rx": .rx.value,
				"title": .title.value
			}
		EOF
		;;
	get)
		read -r -d '' QUERY <<-EOF
			PREFIX meta: <http://semmeddbeh/metathesaurus#>
			PREFIX ttl: <http://semmeddbeh/turtle#>
			PREFIX smdb: <http://semmeddbeh/turtle#>
			SELECT DISTINCT ?subject ?predicate ?object WHERE {
				?subject ${2} '${3}' .
				?subject ?predicate ?object .
			}
		EOF
		read -r -d '' JQE <<-EOF
			[ .results.bindings[0].subject.value, ([ .results.bindings[] | { "key": .predicate.value, "value": .object.value } ] | from_entries) ]
		EOF
		;;
	listAdrs)
		read -r -d '' QUERY <<-EOF
			PREFIX owl: <http://www.w3.org/2002/07/owl#>
			PREFIX meta: <http://semmeddbeh/metathesaurus#>
			PREFIX smdb: <http://semmeddbeh/turtle#>
			SELECT DISTINCT
				?mdr, ?mdrTitle
			WHERE {
				?drug a owl:NamedIndividual .
				?drug meta:CUI ?cui .
				?drug meta:ATC ?atc .
				FILTER(?atc IN ( '${2}' )) .
				BIND(IRI(CONCAT("http://semmeddbeh/turtle#", ?cui)) AS ?smdbSubject) .
				?evidence smdb:has_subject ?smdbSubject .
				?evidence smdb:has_object ?smdbObject .
				?evidence smdb:PMID ?pmid .
				BIND(IRI(REPLACE(STR(?smdbObject), "turtle", "metathesaurus")) AS ?conceptIri) .
				?conceptIri meta:MDR ?mdr .
				?conceptIri rdfs:label ?mdrTitle .
			}
			LIMIT 100
		EOF
		read -r -d '' JQE <<-EOF
			[ .results.bindings[] | { "key": .mdr.value, "value": .mdrTitle.value } ] | from_entries
		EOF
		;;
	*)
		exit 1;
		;;
esac

curl -X 'POST' \
	--silent --show-error --fail \
	-H 'Content-Type: application/sparql-query' \
	-H 'Accept: application/sparql-results+json' \
	-u "${USERNAME}:${PASSWORD}" \
	-d "${QUERY}" \
	"${SERVER}" \
| jq -r "${JQE}"
