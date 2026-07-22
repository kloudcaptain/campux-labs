// Campux Retail — product API (lab demo)
// Zero dependencies on purpose: nothing to `npm install`, so the deploy can't fail on a package step.
// Azure App Service (Linux) injects the port to listen on via process.env.PORT.
// DB_CONNECTION is an app setting whose VALUE is a Key Vault reference. App Service resolves
// the reference using the app's managed identity BEFORE our code runs, so here it is already a
// plain string. Our code never sees a secret in source or in a config file — that is the whole point.

const http = require('http');

const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  const resolved = process.env.DB_CONNECTION || 'NOT SET';
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end(
    'Campux Retail product API\n' +
    '-------------------------\n' +
    'Value App Service resolved for DB_CONNECTION:\n' +
    resolved + '\n\n' +
    'If the line above is a real connection string, the managed identity read the\n' +
    'secret from Key Vault with zero credentials in this code. That is success.\n' +
    'If it still shows @Microsoft.KeyVault(...), the reference did not resolve —\n' +
    'see the Troubleshooting section of the lab.\n'
  );
});

server.listen(port, () => {
  console.log('Campux product API listening on port ' + port);
});
