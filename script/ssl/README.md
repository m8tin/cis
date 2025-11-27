Issuing SSL certificates
========================
There are two modes you can use the script `renewCerts.sh`.

1. dns
2. http



Dns mode
--------
This mode is meant to use inside a docker container defined by the `Dockerfile`.
To configure, build and run the Container there is a file `docker-compose.yml.template`.
You can copy this file to `docker-compose.yml` and set the needed environment variables there.

- __AUTOACME_CONTAINER_HOSTNAME__  
  is used to enable the use of the host name within the container.
  For example, for meaningful commit messages.
- __AUTOACME_GIT_REPOSITORY_VIA_SSH__ (optional)  
  is used to specify a Git repository to which the keys and certificates are transferred.
  Therefore, SSH keys are generated on first launch (`docker compose up -d`) and the repository is cloned to `~/acmeResults/`.
  The public key must be granted __write access__ to the repository  
  (e.g. as repository's deploy key).
  The key can be viewed via `docker compose logs`.
- __AUTOACME_PATH_IN_GIT_REPOSITORY__  (optional)  
  specifies a path inside the repository were the certiticates are saved.  
  (e.g. AUTOACME_PATH_IN_GIT_REPOSITORY="/foo/bar/" => /root/autoACME/foo/bar/your-domain.net/fullchain.crt)
- __AUTOACME_DNS_PROVIDER__  
  sets the provider modul of acme.sh used to communicate with your domain provider.  
  (For further information see: https://github.com/acmesh-official/acme.sh/wiki/dnsapi)

You may have to set additional environment variables depending on your provider...



### Manual docker commands
Instead of using `docker compose` you can build and run the container manually:
```
docker build -t cis/autoacme .
docker run --name autoacme -d cis/autoacme
```
This may be useful for investiagtion...


Http mode
---------
If you plan to use `renewCerts.sh` directly on your host computer this mode may fit your needs.
Here you need a `nginx` webserver. The domain have to point to it and following configuration is needed:

1. The content of folder `/var/www/letsencrypt/.well-known/acme-challenge/` has to be accessable via `http://your-domain.net/.well-known/acme-challenge/`
2. The certificates are stored to `/etc/nginx/ssl`. If this folder is a git repository then changes will be commited and pushed.
3. An entry into the crontab is needed to do automatic updates.
