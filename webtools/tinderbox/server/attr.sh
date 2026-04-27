chmod a+x `find . -name "*.pl"`
chown -R tinderbox:apache *
chown -R apache:apache xml/logs
chmod -R g+w xml/logs
