#!/bin/bash
set -e

LDAP_ALLOW_INSECURE=${LDAP_ALLOW_INSECURE:-false}
SAMBA_REALM=${SAMBA_REALM:-SAMBA.LAN}
SETUP_LOCK_FILE="/var/lib/samba/private/.setup.lock.do.not.remove"

appSetup () {

info () {
    echo "[INFO] $@"
}

# If $SAMBA_PASSWORD is not set, generate a password
SAMBA_PASSWORD=${SAMBA_PASSWORD:-`(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c20; echo) 2>/dev/null`}
export KERBEROS_PASSWORD=${KERBEROS_PASSWORD:-`(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c20; echo) 2>/dev/null`}
info "Samba password set to: $SAMBA_PASSWORD"
info "Kerberos password set to: $KERBEROS_PASSWORD"

# Populate $SAMBA_OPTIONS
SAMBA_OPTIONS=${SAMBA_OPTIONS:-}

[ -n "$SAMBA_DOMAIN" ] \
    && SAMBA_OPTIONS="$SAMBA_OPTIONS --domain=$SAMBA_DOMAIN" \
    || SAMBA_OPTIONS="$SAMBA_OPTIONS --domain=${SAMBA_REALM%%.*}"

[ -n "$SAMBA_HOST_IP" ] && SAMBA_OPTIONS="$SAMBA_OPTIONS --host-ip=$SAMBA_HOST_IP"

# Fix nameserver
echo -e "search ${SAMBA_REALM}\nnameserver 127.0.0.1" > /etc/resolv.conf

# Provision domain
rm -f /etc/samba/smb.conf
rm -rf /var/lib/samba/*
mkdir -p /var/lib/samba/private
samba-tool domain provision \
    --use-rfc2307 \
    --realm=${SAMBA_REALM} \
    --adminpass=${SAMBA_PASSWORD} \
    --server-role=dc \
    --dns-backend=BIND9_DLZ \
    $SAMBA_OPTIONS \
    --option="bind interfaces only"=yes

 ln -sf /var/lib/samba/private/krb5.conf /etc/krb5.conf
    if [ "${LDAP_ALLOW_INSECURE,,}" == "true" ]; then
	     sed -i "/\[global\]/a \\\t\# enable unencrypted passwords\nldap server require strong auth = no" /etc/samba/smb.conf
	  fi
    # Create Kerberos database
    expect kdb5_util_create.expect

    # Export kerberos keytab for use with sssd
    if [ "${OMIT_EXPORT_KEY_TAB}" != "true" ]; then
        samba-tool domain exportkeytab /etc/krb5.keytab --principal ${HOSTNAME}\$
fi

# Move smb.conf
mv /etc/samba/smb.conf /var/lib/samba/private/smb.conf
ln -sf /var/lib/samba/private/smb.conf /etc/samba/smb.conf
mv /etc/samba/smbusers /var/lib/samba/private/smbusers
ln -sf /var/lib/samba/private/smbusers /etc/samba/smbusers

# Update dns-forwarder if required
[ -n "$SAMBA_DNS_FORWARDER" ] \
    && sed -i "s/dns forwarder = .*/dns forwarder = $SAMBA_DNS_FORWARDER/" /var/lib/samba/private/smb.conf

# Mark samba as setup
touch "${SETUP_LOCK_FILE}"

# Setup only?
[ -n "$SAMBA_SETUP_ONLY" ] && exit 127 || :

}

appStart () {
    # ssh
    if [ -f "/runssh.sh" ]; then /runssh.sh; fi
    # setup
    if [ ! -f "${SETUP_LOCK_FILE}" ]; then
      appSetup
    fi
    # run
    /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
}

appHelp () {
	echo "Available options:"
	echo " app:start          - Starts all services needed for Samba AD DC"
	echo " app:setup          - First time setup."
	echo " app:setup_start    - First time setup and start."
	echo " app:help           - Displays the help"
	echo " [command]          - Execute the specified linux command eg. /bin/bash."
}

case "$1" in
	app:start)
		appStart
		;;
	app:setup)
		appSetup
		;;
	app:setup_start)
		appSetup
		appStart
		;;
	app:help)
		appHelp
		;;
	*)
		if [ -x $1 ]; then
			$1
		else
			prog=$(which $1)
			if [ -n "${prog}" ] ; then
				shift 1
				$prog $@
			else
				appHelp
			fi
		fi
		;;
esac

exit 0
