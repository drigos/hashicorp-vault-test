
## Run Hashicorp Vault server

```
docker container run --rm --cap-add=IPC_LOCK -it --name vault -v $(pwd)/config.hcl:/vault/config/config.hcl:ro -p 8200:8200 -p 8250:8250 vault vault server -config=/vault/config/config.hcl
```

## Run script (first time)

```
./init.sh
```

## Run script (second time)

```
export UNSEAL_KEY=<unseal-key>
export ROOT_TOKEN=<root-token>
./init.sh
```
