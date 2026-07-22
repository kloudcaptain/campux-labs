// Campux Retail — staff portal (lab demo)
// Zero dependencies on purpose: nothing to `npm install`, so the deploy can't fail on a package step.
//
// This app is protected by App Service built-in authentication (Easy Auth). By the time a request
// reaches this code, App Service has already completed the OpenID Connect sign-in with Microsoft
// Entra ID and injected the signed-in user's details as request headers. We never write a single
// line of auth code — that is the whole point of the lab.
//
// Full ID-token claims are available at /.auth/me (served by the platform, not by this code).

const http = require('http');

const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  const name = req.headers['x-ms-client-principal-name'] || '(no authenticated user)';
  const idp = req.headers['x-ms-client-principal-idp'] || '(none)';
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end(
    'Campux Retail — Staff Portal\n' +
    '============================\n' +
    'Signed-in user: ' + name + '\n' +
    'Identity provider: ' + idp + '\n\n' +
    'You reached this page only AFTER signing in with Microsoft Entra ID.\n' +
    'This app contains no authentication code — App Service handled the whole\n' +
    'OpenID Connect flow and passed your identity in the request headers.\n\n' +
    'To see the full set of ID-token claims (name, email, oid, tenant, ...),\n' +
    'visit /.auth/me on this same site.\n'
  );
});

server.listen(port, () => {
  console.log('Campux staff portal listening on port ' + port);
});
