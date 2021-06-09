
## Run Hashicorp Vault server

```
docker container run --rm --cap-add=IPC_LOCK -it --name vault -v $(pwd)/config.hcl:/vault/config/config.hcl:ro -p 8200:8200 -p 8250:8250 vault vault server -config=/vault/config/config.hcl
```

## Run script (first time)

```
./init.sh
```

## Run script (second time)

A inicialização só pode ser executada uma vez, por tanto para as demais execuções é necessário exportar as variáveis abaixo:

```
export UNSEAL_KEY=<unseal-key>
export ROOT_TOKEN=<root-token>
./init.sh
```

## Descritivo

- Dentro de `utils.sh` existe:
    - Uma função genérica para ativar os métodos de autenticação
    - Uma função genérica para testar as roles criadas
- A estrutura dos endpoints estão personalizadas para propósitos de demonstração
    - Com endpoints personalizados é necessário especificá-los ao logar na UI
    - Em produção o ideal é a utilização da estrutura padrão para simplificar a utilização
- Teste do método OIDC: é necessário configurar variáveis de ambiente
    - GitLab: `GITLAB_APPLICATION_ID`, `GITLAB_SECRET` e `GITLAB_GROUP`
    - Google:
- Teste do método JWT:
    - Em produção é necessário a geração de um par de chaves pública e privadas
    - Para fins de teste tais chaves são geradas aqui pelo arquivo `jwt_utils.sh`
