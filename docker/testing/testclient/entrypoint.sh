#!/usr/bin/env bash

TESTCLIENT_SSH_PRIVATE_KEY=/keys/ssh_host_rsa_key
TESTCLIENT_SSH_PUBLIC_KEY=/keys/ssh_host_rsa_key.pub

function softserve_new_repo() {
	local name="$1"
	local description="$2"
	ssh softserve repo create ${name} '-d '"${description}"''
}

function softserve_ready() {
	while ! ssh softserve info > /dev/null; do
		echo "Waiting for softserve to be ready..."
		sleep 1
	done
}

if [ ! -z "$TESTCLIENT_SSH_PRIVATE_KEY" ]; then
	mkdir -p ${HOME}/.ssh
	chmod 700 ${HOME}/.ssh
	cat "$TESTCLIENT_SSH_PRIVATE_KEY" > ${HOME}/.ssh/id_rsa
	cat "$TESTCLIENT_SSH_PUBLIC_KEY" > ${HOME}/.ssh/id_rsa.pub
	chmod 600 ${HOME}/.ssh/id_rsa
	chmod 600 ${HOME}/.ssh/id_rsa.pub

	echo "Host softserve" >> ${HOME}/.ssh/config
	echo "  User git" >> ${HOME}/.ssh/config
	echo "  IdentityFile ${HOME}/.ssh/id_rsa" >> ${HOME}/.ssh/config
	echo "  StrictHostKeyChecking no" >> ${HOME}/.ssh/config
	echo "" >> ${HOME}/.ssh/config
fi

git config --global user.email "test@example.com"
git config --global user.name "Test User"
git config --global init.defaultBranch master

gpgDecrypt() {
	local file="$1"
	local output="$2"
	echo "password" | gpg --pinentry-mode loopback --passphrase-fd 0 -r testuser@notarealemail.com -o "$output" -d "$file"
}

gpgEncrypt() {
	local file="$1"
	local output="$2"
	echo "password" | gpg --pinentry-mode loopback --passphrase-fd 0 -r testuser@notarealemail.com -o "$output" -e "$file"
}

generatePassEntry() {
	local login="$1"
	local folder="$2"
	local sitename="$3"
	local notes="$4"

	if [ ! -d "$folder" ]; then
		mkdir -p "$folder"
	fi

	echo "$(randomPassword)" > $folder/$sitename.txt
	echo "login: $login" >> $folder/$sitename.txt
	echo "url: $sitename" >> $folder/$sitename.txt

	if [ ! -z "$notes" ]; then
		echo "notes: $notes" >> $folder/$sitename.txt
	fi
	gpgEncrypt $folder/$sitename.txt $folder/$sitename.gpg
	rm $folder/$sitename.txt

	echo "Generated password for $folder/$sitename.gpg"

	# only for testing
	gpgDecrypt $folder/$sitename.gpg $folder/$sitename.txt
	cat $folder/$sitename.txt
	rm $folder/$sitename.txt
}

randomPassword() {
	# Generate a random password using dd and md5sum
	dd if=/dev/urandom bs=1 count=32 2>/dev/null | md5sum | cut -c -32
}

set -e

gpg --batch --gen-key <<EOF
Key-Type: 1
Key-Length: 2048
Subkey-Type: 1
Subkey-Length: 2048
Name-Real: Test User
Name-Email: testuser@notarealemail.com
Expire-Date: 0
Passphrase: password
%commit
%echo done
EOF

gpg --list-keys
gpg --list-secret-keys

# Test the key can encrypt and decrypt.
echo "Testing that the key can encrypt and decrypt."
echo "This is a test" > /tmp/testfile
gpgEncrypt /tmp/testfile /tmp/testfile.asc

rm /tmp/testfile
gpgDecrypt /tmp/testfile.asc /tmp/testfile
cat /tmp/testfile

# Cleanup
rm /tmp/testfile
rm /tmp/testfile.asc
echo "Key can encrypt and decrypt."

set +e

## Setup softserve

# Wait for softserve to be ready
softserve_ready

# Initialize git repository
i=1
mkdir -p repositories/icecream$i
(
	softserve_new_repo "icecream$i" "My softserve icecream $i"
	cd repositories/icecream$i
	git init
	for j in $(seq 1 10); do
		printf "# icecream$i\n\nCommit: $j" > README.md

		for site in "fakewebsite.com" "anotherwebsite.com" "example.com"; do
			generatePassEntry "testuser" "Business" "$site" "This is a test entry for $site"
		done

		for site in "rootwebsite.com" "google.com" "facespace.com"; do
			generatePassEntry "testuser" "." "$site" "This is a test entry for $site"
		done

		git add .
		git commit -m "icecream$i commit $j"
	done

	git remote add origin git@softserve:/icecream$i.git

	while ! git push -u origin master; do
		echo "git push failed, retrying..."
		sleep 1
	done

	git push --tags
)

# cleanup
rm -rf repositories/icecream$i

# Initialize git repository that uses LFS to store gpg files
i=2
mkdir -p repositories/icecream$i
(
	softserve_new_repo "icecream$i" "My softserve icecream $i"
	cd repositories/icecream$i
	git init
	printf "# icecream$i\n\nCommit: $j" > README.md
	git add README.md
	git commit -m "icecream$i commit 1"
	git remote add origin git@softserve:/icecream$i.git
	while ! git push -u origin master; do
		echo "git push failed, retrying..."
		sleep 1
	done

	# git config -f .lfsconfig lfs.url http://test:password@gitbucket/test/repo$i.git/info/lfs
	# git add .lfsconfig
	git lfs install
	git lfs track "*.gpg"
	git add .gitattributes

	for site in "fakewebsite.com" "anotherwebsite.com" "example.com"; do
		generatePassEntry "testuser" "Business" "$site" "This is a test entry for $site"
	done

	for site in "rootwebsite.com" "google.com" "facespace.com"; do
		generatePassEntry "testuser" "." "$site" "This is a test entry for $site"
	done

	git add .
	git commit -m "icecream$i lfs commit 2"
	git push
)

# cleanup
rm -rf repositories/icecream$i

# DONE
sleep infinity
