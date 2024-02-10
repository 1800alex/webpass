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

echo | gpg &>/dev/null || true
mkdir -p /home/test/.gnupg
chown -R test:test /home/test/.gnupg
chmod 700 /home/test/.gnupg

## Setup softserve

# Wait for softserve to be ready
softserve_ready

# Initialize 5 git repositories, each with 10 commits and 10 tags
for i in $(seq 1 5); do
	mkdir -p repositories/icecream$i
	(
		softserve_new_repo "icecream$i" "My softserve icecream $i"
		cd repositories/icecream$i
		git init
		for j in $(seq 1 10); do
			printf "# icecream$i\n\nCommit: $j" > README.md
			git add README.md
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
done

# Initialize 5 git repositories, each with an LFS binary file
for i in $(seq 6 10); do
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
		git lfs track "*.bin"
		git add .gitattributes
		dd if=/dev/urandom of=file.bin bs=512 count=1
		md5sum file.bin > file.bin.md5
		git add file.bin file.bin.md5
		git commit -m "icecream$i lfs commit 2"
		git push
	)

	# cleanup
	rm -rf repositories/icecream$i
done

# DONE
sleep infinity
