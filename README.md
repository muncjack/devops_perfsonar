This repo holds roles and files to manage the perfSONAR Debian repository setup.

To add a release, change the release variable in the inventory, then run:

  ansible-playbook -t release repo-servers.yaml

After that, the Jenkins setup still need to be double checked and the new version added there.
And the new release needs to be added to this script: debian-docker-buildmachines/deb-repo/staging-repo-publish.sh
