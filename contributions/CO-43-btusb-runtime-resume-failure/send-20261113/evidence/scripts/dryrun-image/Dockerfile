# An image for git send-email --dry-run only (run with --network none): the list bot's image
# plus Ubuntu's git-email package, which the bot's image lacks.
FROM bluez-action-ci:60348956fc7b
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git-email && rm -rf /var/lib/apt/lists/*
