# Will enable and update image cleanup policy (Project -> Settings -> CI/CD -> Clean up image tags)
# https://docs.gitlab.com/ee/user/packages/container_registry/reduce_container_registry_storage.html
# Requirements: jq

GITLAB_URL="https://gitlab.example.com"
TOKEN="asfdk24ij5123j123j15" # Personal Access Token
ID=$(curl -s "$GITLAB_URL/api/v4/projects?private_token=$TOKEN&per_page=300" | jq '.[] | select(.namespace.name=="example_filter_by_namespace") | .id')

for i in $ID; do \
  curl --request PUT --header 'Content-Type: application/json;charset=UTF-8' --header "PRIVATE-TOKEN: $TOKEN" \
  --data-binary '{"container_expiration_policy_attributes":{"cadence":"1d","enabled":true,"keep_n":5,"older_than":"30d","name_regex":".*","name_regex_keep":"prod-.*"}}' \
  "$GITLAB_URL/api/v4/projects/$i" \
  ; done
