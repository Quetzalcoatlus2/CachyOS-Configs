# CachyOS configuration deployment

The CachyOS tree is home/ and system/. ubuntu-thinkpad/ stays separate; do not deploy the CachyOS system tree on Ubuntu. Its existing autotiling startup entry is unchanged.

## Commands

Run as the normal desktop user, never sudo the whole script. Use git pull --ff-only to download commits. sync.sh collect (legacy alias: pull) copies live files INTO the repository; it never downloads commits.

```sh
bash sync.sh check
bash sync.sh deploy --dry-run
bash sync.sh deploy
bash sync.sh setup-timers
```

Only Git-tracked regular files under home/ and system/ are deployed. Untracked files are ignored; review and git add intended configuration files before deploying them. Executable permissions come from the Git index, not a blanket chmod. Validation checks shell syntax, Zsh syntax, Python-script parsing, duplicate JSON keys and Sway config syntax. It is not a full runtime test.

Deploy backs up each overwritten file under the printed private state directory and records destination paths in manifest.tsv. originally-absent.txt records newly created destinations. Backups mirror the repository paths. Deployment is not transactional and does not perform automatic rollback; restore the affected backup files to their recorded destinations if necessary. System backups may require sudo to read or restore. collect also backs up repository files before replacing them.

## Snapshots and maintenance

The existing /usr/local/bin/snapper-fifo.py implementation is preserved and required. The cleanup-service drop-in changes its argument from --limit 500 to --limit 100 without clearing vendor ExecStartPre/ExecStopPost hooks, including Limine's lock. The script itself has not been imported or audited here; restore your original implementation before deploying to a fresh machine. No alternate deletion algorithm is introduced.

NUMBER_CLEANUP, TIMELINE_CREATE, TIMELINE_CLEANUP and EMPTY_PRE_POST_CLEANUP must remain no in /etc/snapper/configs/root. Deploy refuses unexpected policy values. NUMBER_LIMIT and NUMBER_LIMIT_IMPORTANT are inactive while number cleanup is disabled; the operative cap is the FIFO command's --limit 100. Existing script rules, including any protection exceptions, remain unchanged.

Deploy reloads systemd but does not explicitly start snapshot cleanup, restart zram, apply sysctls, restart applications or change the kernel. The next scheduled cleanup uses the new limit and may delete snapshots exceeding it. setup-timers separately records prior enablement states, disables the unused timeline timer and enables cleanup, paccache and root Btrfs scrub timers. Starting timers can trigger overdue maintenance jobs.

Paccache keeps three versions per package while protecting files modified within 30 days. This is not a fixed disk-space cap or deletion of everything older than 30 days.

## Desktop activation

Autotiling is loaded through the existing include /etc/sway/config.d/* using system/etc/sway/config.d/99-autotiling.conf. exec avoids duplicate helpers on config reload. For this session, start it only if absent:

```sh
swaymsg reload
pgrep -u "$(id -u)" -x autotiling >/dev/null || swaymsg exec autotiling
```

Restart Waybar or log out and back in to load its restored CPU sensor. The sensor path is verified for the Ryzen laptop, not universal across different hardware. Exit Brave normally and reopen it to load the restored feature list. Other Brave workarounds and the 12 GiB zram configuration are unchanged.
