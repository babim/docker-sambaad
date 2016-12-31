## Samba 4 AD container based on Alpine Linux

### Credits
Some parts are collected from:
* https://github.com/pitkley/dockerfiles/tree/master/samba-ad-dc
* https://github.com/tkaefer/alpine-samba-ad-container
* https://wiki.samba.org/index.php/Samba,_Active_Directory_%26_LDAP


### Usage

Without any config and thrown away when terminated:
```
docker run -it --rm babim/sambaad
```
```
docker run --rm -i -t \
    -e SAMBA_REALM="SAMBA.LAN" \
    -e SAMBA_DOMAIN="samba" \
    -e SAMBA_PASSWORD="Password1!" \
    -e SAMBA_HOST_IP="192.168.1.10" \
    -e SAMBA_DNS_FORWARDER="192.168.1.1" \
    -v ${PWD}/samba:/var/lib/samba \
    -h addomain \
    babim/sambaad:bind
```
Production deploy
```
docker run -h addomain -d \
    -e SAMBA_REALM="SAMBA.LAN" \
    -e SAMBA_DOMAIN="samba" \
    -e SAMBA_PASSWORD="Password1!" \
    -e SAMBA_HOST_IP="192.168.1.10" \
    -e SAMBA_DNS_FORWARDER="192.168.1.1" \
    -v ${PWD}/libsamba:/var/lib/samba \
    -v ${PWD}/krb5kdc:/var/lib/krb5kdc \
    -v ${PWD}/etcsamba:/etc/samba \
    --name addomain --privileged --network=host \
    babim/sambaad:bind
```
note:
* REALM always need UPPERLETTER
* DOMAIN need lowerletter

### Environment variables

Environment variables are controlling the way how this image behaves therefore please check this list an explanation:

* SAMBA_REALM (required) The realm (comparable to the FQDN) for the domain controller (default. samba.lan).
* SAMBA_DOMAIN (optional) The domain (comparable to the NetBios-name) for the domain controller (default: samba). If it is not supplied, the first part of the FQDN/SAMBA_REALM will be used.
* SAMBA_PASSWORD (optional) The password for the DC-Administrator. If not supplied, a random, 20 character long alphanumeric password will be generated and printed to stdout.
* SAMBA_OPTIONS (optional) Additional options for samba-tool domain provision.
* SAMBA_HOST_IP (optional) Set the IPv4 address during provisioning. (If you need to set a IPv6 address, supply --host-ip6=IP6ADDRESS through SAMBA_OPTIONS.)
* KERBEROS_PASSWORD (optional) The kerberos password  if not set will set to `$(pwgen -cny 10 1)`

### Use existing data

The first time you start the container, a setup-script will run and provision the domain controller using the supplied environment variables. After the setup has finished successfully, the container will continue starting (unless SAMBA_SETUP_ONLY is set) and start the domain controller.

The container saves all necessary files within /var/lib/samba. See the following examples on how to start/setup the domain controller and how to persist this volume.

Using (or reusing data) is done by providing
* `/var/lib/samba/private/smb.conf`
* `/etc/krb5.conf > link to /var/lib/samba/private/krb5.conf`
* `/usr/lib/samba/`
* `/var/lib/krb5kdc/`
* `/etc/samba/`

as volumes to the docker container.
