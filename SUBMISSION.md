# Submission

Fork URL: <!-- paste the URL of your fork here -->

## Files to commit

- [ ] `ansible.cfg`: your Ansible settings
- [ ] `inventory.ini`: the three servers, grouped by role
- [ ] `site.yml`: the playbook
- [ ] `templates/pollie.conf.j2`: the Nginx site template

## Questions

Answer in your own words. Where a question asks for output, paste it in a code block.

### Q1. Before Ansible: paste the `ssh` command you used to log in to `pa-web` and the output of `hostname; cat /etc/os-release | head -2; which nginx`. Now imagine 30 servers: what exactly would you repeat, and what is the chance all 30 end up identical?

**Your answer:**

<!-- replace this line with your answer -->

### Q2. Paste your `inventory.ini` and the output of `ansible-inventory --graph`. Why groups (`web`, `app`, `db`) and not just a list of three hosts? What does `[servers:children]` give you?

**Your answer:**

<!-- replace this line with your answer -->

### Q3. Paste `ansible all -m ping` and one ad-hoc command you ran (for example `-m command -a "uptime"` or `-m setup -a "filter=ansible_distribution*"`). What does `ping` check that the shell command of the same name does not? What does `-b` do?

**Your answer:**

<!-- replace this line with your answer -->

### Q4. Run your playbook twice. Paste the `PLAY RECAP` of the first run and of the second. Why must the second say `changed=0`, and which of your tasks would have broken that if you had used `command` or `shell` instead of a module?

**Your answer:**

<!-- replace this line with your answer -->

### Q5. Change one line of the Nginx template (for example the `server_name` or a header), run again and paste the recap. Which task changed, which handler ran, and on how many hosts? What would have happened to a running Nginx if the config was changed without a handler?

**Your answer:**

<!-- replace this line with your answer -->

### Q6. Run `./drift.sh` (it simulates three people logging in to "just fix one thing"), then `ansible-playbook site.yml --check --diff` before applying. Paste what Ansible says it would change and why `--check` is the command you run on a production system first. Then apply and paste the recap.

**Your answer:**

<!-- replace this line with your answer -->

### Q7. You used the `apt`, `service`/`systemd`, `copy` or `template`, `user` and `file` modules. For each, one sentence: what state does it describe, and how does it know nothing needs doing?

**Your answer:**

<!-- replace this line with your answer -->

### Q8. Paste the output of `./verify.sh`. It must end with **ALL CHECKS PASSED**.

**Your answer:**

<!-- replace this line with your answer -->

### Q9. **Tear down.** Paste the output of `./verify-teardown.sh`. It must end with **TEARDOWN VERIFIED**.

**Your answer:**

<!-- replace this line with your answer -->
