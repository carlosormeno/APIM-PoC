SHELL := /bin/bash

.PHONY: render-gravitee render-wso2 render-kong

render-gravitee:
	@helm template gravitee gravitee/apim \
		-n apim-gravitee \
		-f APIM/gravitee/values.yaml \
		> manifests/gravitee/rendered.yaml
	@echo "Rendered manifests/gravitee/rendered.yaml"

render-wso2:
	@helm template wso2apim wso2/wso2am \
		-n apim-wso2 \
		-f APIM/wso2/values.yaml \
		> manifests/wso2/rendered.yaml
	@echo "Rendered manifests/wso2/rendered.yaml"

render-kong:
	@helm template kong kong/kong \
		-n apim-kong \
		-f APIM/kong/values.yaml \
		> manifests/kong/rendered.yaml
	@echo "Rendered manifests/kong/rendered.yaml"
