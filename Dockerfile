FROM httpd
RUN set -eux; \
	\
	# mod_http2 mod_lua mod_proxy_html mod_xml2enc
	# https://anonscm.debian.org/cgit/pkg-apache/apache2.git/tree/debian/control?id=adb6f181257af28ee67af15fc49d2699a0080d4c
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		build-essential \
		ca-certificates \
		git \
		make \
	; \
	\
	cd /usr/local/src/; \
	git clone https://github.com/gavincarr/mod_auth_tkt.git; \
	cd mod_auth_tkt; \
	./configure --apxs=/usr/local/apache2/bin/apxs; \
	make; \
	make install; \
	cp -r cgi/ /usr/local/apache2/cgi-bin/; \
	cp conf/02_auth_tkt.conf /usr/local/apache2/conf/extra/http-auth-tkt.conf; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	find /usr/local -type f -executable -exec ldd '{}' ';' \
		| awk '/=>/ { print $(NF-1) }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -r apt-mark manual \
	; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	\
	apt-get install -y --no-install-recommends libcgi-pm-perl libapache-htpasswd-perl; \
	\
	rm -r /var/lib/apt/lists/*; \
	\
# smoke test
	httpd -v

COPY overlay /

RUN set -eux; \
	\
# configure the demo
	echo "Include conf/extra/httpd-auth-tkt.conf" >> /usr/local/apache2/conf/httpd.conf; \
	chmod -R +x /usr/local/apache2/cgi-bin/* /usr/local/apache2/htdocs/auth/*.cgi;  /usr/local/apache2/htdocs/protected/*.cgi; \
	htpasswd -cb /usr/local/apache2/conf/htpasswd test-user test-password; \
	\
# check the configuration
	httpd -T
