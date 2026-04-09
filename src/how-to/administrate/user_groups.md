<a id="scim_user_groups"></a>

# Manage user groups using the SCIM API

Wire has recently added the capability to manage user groups via the SCIM protocol.

If you need to manage user groups manually via SCIM, for example for provisioning or synchronization purposes, you can use the SCIM Group endpoints exposed by the `spar` service.

Before proceeding, make sure you have:

- Access to the Kubernetes infrastructure under your Wire deployment (EG: you can run `kubectl` commands)
- A valid `$SCIM_TOKEN` (see the previous section on how to generate SCIM tokens)

First, open a terminal and create a port-forward to your `spar` component:

```sh
kubectl port-forward -n wire svc/spar 9999:8080
```

This is what you will use to talk to your Wire service. This makes the `spar` component directly accessible from your workstation.
Make sure you close said terminal when you are done talking to `spar`.

## Create a group using the SCIM API

To create a new SCIM-managed user group containing two users, run:

```sh
SPAR_HOST=http://localhost:9999
SCIM_TOKEN=YOURSCIMTOKENGOESHERE
GROUP_NAME=...
USER_ID_1=...
USER_ID_2=...

curl -s --show-error \
  -X POST "$SPAR_HOST/scim/v2/Groups" \
  -H "Authorization: Bearer $SCIM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "displayName": "'"$GROUP_NAME"'",
    "members": [
      {
        "value": "'"$USER_ID_1"'"
      },
      {
        "value": "'"$USER_ID_2"'"
      }
    ]
  }'
```

Where:
* `$SCIM_TOKEN` is your SCIM authentication token
* `$GROUP_NAME` is the name of the group to create
* `$USER_ID_1` and `$USER_ID_2` are the UUIDs of users to include in the group

What does this do?:
* This creates your user group, then provides you with the UUID of your newly created user group.

Notes:
* The team ID is extracted from the SCIM token. You do not have to supply it.
* All users added must already exist and be managed by SCIM.
* If any referenced user does not exist in Wire, the whole request fails.
* The group is automatically created with the `managed_by` field set to `scim`. This distinguishes groups created in this fashion from the `managed_by: wire` user groups.

## Retrieve a group using the SCIM API
 
To retrieve a SCIM-managed user group, run:
 
```sh
SPAR_HOST=http://localhost:9999
SCIM_TOKEN=YOURSCIMTOKENGOESHERE
GROUP_ID=...
 
curl -X GET \
  --header "Authorization: Bearer $SCIM_TOKEN" \
  --header 'Accept: application/json' \
  "$SPAR_HOST/scim/v2/Groups/$GROUP_ID"
```

Where:
* `$SCIM_TOKEN` is your SCIM authentication token
* `$GROUP_ID` is the UUID of the group to retrieve

Notes:
* Only groups with `managed_by: scim` are visible through this endpoint.
* If the group does not exist in Wire, the request fails.
* If the group exists but is not SCIM-managed, the request fails.

## Retrieve all groups using the SCIM API

To retrieve all SCIM-managed user groups, run:
 
```sh
SPAR_HOST=http://localhost:9999
SCIM_TOKEN=YOURSCIMTOKENGOESHERE
 
curl -X GET \
  --header "Authorization: Bearer $SCIM_TOKEN" \
  --header 'Accept: application/json' \
  "$SPAR_HOST/scim/v2/Groups"
```

Where:
* `$SCIM_TOKEN` is your SCIM authentication token

Notes:
* Only groups with `managed_by: scim` are visible through this endpoint.
* This endpoint may support name filtering, depending on the filters supplied by the client.


## Modify a group using the SCIM API

To modify a SCIM-managed user group, run:
 
```sh
SPAR_HOST=http://localhost:9999
SCIM_TOKEN=YOURSCIMTOKENGOESHERE
GROUP_ID=...
GROUP_NAME=...
USER_ID_1=...
USER_ID_2=...
 
curl -X PUT \
  --header "Authorization: Bearer $SCIM_TOKEN" \
  --header 'Content-Type: application/json' \
  -d '{
    "displayName": "'"$GROUP_NAME"'",
    "members": [
      {
        "value": "'"$USER_ID_1"'"
      },
      {
        "value": "'"$USER_ID_2"'"
      }
    ]
  }' \
  "$SPAR_HOST/scim/v2/Groups/$GROUP_ID"
```

Where:
* `$SCIM_TOKEN` is your SCIM authentication token
* `$GROUP_ID` is the UUID of the group to modify
* `$GROUP_NAME` is the name the group should have after the modification
* `$USER_ID_1` and `$USER_ID_2` are the UUIDs of the users that should be part of the group after the modification

What does this do?
* Users that are part of the SCIM payload but not currently part of the Wire user group are added to the Wire user group.
* Users that are currently part of the Wire user group but not present in the SCIM payload are removed from the Wire user group.

Notes:
* Only groups with `managed_by: scim` can be modified through this endpoint.
* The payload must contain the full desired state of the group.
* The group display name in the SCIM payload is compared with the one currently stored in Wire.
* All users added must already exist and be managed by SCIM.
* If any user that is to be added does not exist in Wire, the whole request fails.
* The SCIM PATCH operation is not yet implemented for groups. Only full updates via PUT are supported.

## Delete a group using the SCIM API

To delete a SCIM-managed user group, run:
 
```sh
SPAR_HOST=http://localhost:9999
SCIM_TOKEN=YOURSCIMTOKENGOESHERE
GROUP_ID=...
 
curl -X DELETE \
  --header "Authorization: Bearer $SCIM_TOKEN" \
  "$SPAR_HOST/scim/v2/Groups/$GROUP_ID"
```

Where:
* `$SCIM_TOKEN` is your SCIM authentication token
* `$GROUP_ID` is the UUID of the group to delete

Notes:
* Only groups with `managed_by: scim` can be deleted through this endpoint.
* If the group does not exist in Wire, the request fails.
* If the group exists but is not SCIM-managed, the request fails.


