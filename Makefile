SHELL := /bin/bash

.PHONY: render-gravitee render-wso2 render-kong render-all \
        apply-gravitee apply-wso2 apply-kong apply-all

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

render-all: render-gravitee render-wso2 render-kong

apply-gravitee:
	@kubectl apply -f manifests/gravitee/rendered.yaml
	@echo "Applied manifests/gravitee/rendered.yaml"

apply-wso2:
	@kubectl apply -f manifests/wso2/rendered.yaml
	@echo "Applied manifests/wso2/rendered.yaml"

apply-kong:
	@kubectl apply -f manifests/kong/rendered.yaml
	@echo "Applied manifests/kong/rendered.yaml"

apply-all: apply-gravitee apply-wso2 apply-kong
