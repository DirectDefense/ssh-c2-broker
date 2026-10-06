#!/usr/bin/env bash
c2_username=c2
read -r -p "Use the included sshd_config file? [y/N] " reply
case "$reply" in
  [Yy]|[Yy][Ee][Ss])
    cp -p /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak"
    cp /opt/ssh-c2-broker/Server/sshd_config /etc/ssh/sshd_config
    echo "Installed included sshd_config."
    ;;
  *)
    echo "Skipped."
    ;;
esac
#add user c2
echo "Enter password for user $c2_username: "
hashed_pw_c2="$(openssl passwd -6)"
useradd -m -s /bin/rbash -p "$hashed_pw_c2" $c2_username 
#install tools
apt-get update
apt-get install bc net-tools -y
set -u
TOOLS=(
    cat
    sort
    cut
    tail
    sed
    netstat
    bc
    head
    grep
    echo
)
for tool in "${TOOLS[@]}"; do
    if [[ -x "/usr/bin/$tool" ]]; then
        echo "OK: /usr/bin/$tool"
    else
        echo "MISSING: $tool not found in /usr/bin" >&2
    fi
done
#copy server files
cp /opt/ssh-c2-broker/Server/configfiles/*.txt /home/$c2_username/
cp /opt/ssh-c2-broker/Server/configfiles/*.sh /usr/bin/
chown -R $c2_username:$c2_username /home/$c2_username
#restart ssh service
service ssh restart