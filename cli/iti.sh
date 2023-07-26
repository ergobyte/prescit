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

SERVER='http://semantic-db.iti.gr/repositories/drugbank-repo'
USERNAME=''
PASSWORD=''

case $1 in
	updateDrugBankIds)
		read -r -d '' QUERY <<-EOF
			PREFIX drugbank: <http://www.semanticweb.org/drugbank-ontology#>
			SELECT DISTINCT ?drugBankId ?unii
			WHERE {
				?d a drugbank:Drug .
				?d drugbank:drugbankID ?drugBankId .
				?d drugbank:unii ?unii .
			}
		EOF
		read -r -d '' JQE <<-EOF
			.results.bindings[]
			| {
				"unii": .unii.value,
				"id": .drugBankId.value | capture("(?<id>[1-9][0-9]+)") | .id | tonumber
			}
			| @text "UPDATE DrugSubstance s SET s.drugBankId = \(.id) WHERE s.drugBankId IS NULL AND s.molecularStructure_id = servo_GetCodeId('2.16.840.1.113883.4.9', '\(.unii)');"
		EOF
		;;
	updatePubChemIds)
		read -r -d '' QUERY <<-EOF
			PREFIX drugbank: <http://www.semanticweb.org/drugbank-ontology#>
			SELECT DISTINCT ?drugBankId ?pubChemId
			WHERE {
				?d a drugbank:Drug .
				?d drugbank:drugbankID ?drugBankId .
				?d drugbank:pubChemSubstance ?pubChemId .
			}
		EOF
		read -r -d '' JQE <<-EOF
			.results.bindings[]
			| {
				"drugBankId": .drugBankId.value | capture("(?<id>[1-9][0-9]+)") | .id | tonumber,
				"pubChemId": .pubChemId.value
			}
			| @text "UPDATE DrugSubstance s SET s.pubChemId = \(.pubChemId) WHERE s.drugBankId = \(.drugBankId);"
		EOF
		;;
	listCategories)
		read -r -d '' QUERY <<-EOF
			PREFIX drugbank: <http://www.semanticweb.org/drugbank-ontology#>
			SELECT DISTINCT ?c ?title
			WHERE {
				?c a drugbank:Category .
				?c drugbank:categoryName ?title .
			}
		EOF
		read -r -d '' JQE <<-EOF
			.results.bindings[]
			| {
				"code": .c.value | capture("#Category_(?<code>.*)") | .code,
				"title": .title.value
			}
			| @text "\(.code) = \(.title)"
		EOF
		;;
	listProductsByDrug)
		read -r -d '' QUERY <<-EOF
			PREFIX drugbank: <http://www.semanticweb.org/drugbank-ontology#>
			SELECT ?drugBankId ?productName
			WHERE {
				?d a drugbank:Drug .
				?d drugbank:drugbankID ?drugBankId .
				?d drugbank:product ?p .
				?p a drugbank:Product .
				?p drugbank:productName ?productName .
			}
			LIMIT 150
		EOF
		read -r -d '' JQE <<-EOF
			[ .results.bindings[]
			| {
				"id": .drugBankId.value,
				"title": .productName.value
			} ]
			| group_by(.id)
			| map({ "id": .[0].id, "productNames": [ .[].title ] | unique | sort | join(", ") })
		EOF
		;;
	listNarratives)
		read -r -d '' QUERY <<-EOF
			PREFIX drugbank: <http://www.semanticweb.org/drugbank-ontology#>
			SELECT DISTINCT ?drugBankId ?text
			WHERE {
				?d a drugbank:Drug .
				?d drugbank:drugbankID ?drugBankId .
				?d drugbank:${2} ?text .
			}
		EOF
		read -r -d '' JQE <<-EOF
			.results.bindings[]
			| {
				"drugBankId": .drugBankId.value | capture("(?<id>[1-9][0-9]+)") | .id | tonumber,
				"text": .text.value
			}
		EOF
		;;
	listAtcCodes)
		read -r -d '' QUERY <<-EOF
			PREFIX drugbank: <http://www.semanticweb.org/drugbank-ontology#> 
			PREFIX xsd: <http://www.w3.org/2001/XMLSchema#> 
			PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			SELECT ?drugBankId ?atc WHERE {
				?d a drugbank:Drug .
				?d drugbank:drugbankID ?drugBankId .
				?d drugbank:atc-code ?atcList .
			    ?atcList rdf:rest*/rdf:first ?atc .
			}
			EOF
		read -r -d '' JQE <<-EOF
			.results.bindings[]
			| {
				"drugBankId": .drugBankId.value | capture("(?<id>[1-9][0-9]+)") | .id | tonumber,
				"atc": .atc.value
			}
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
	${SERVER}?infer=true \
| jq -r "${JQE}"
