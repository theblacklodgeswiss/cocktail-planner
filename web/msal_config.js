// Microsoft Graph / MSAL configuration
// Replace MSAL_CLIENT_ID and MSAL_TENANT_ID with your Azure AD app registration values.
// These can be set via environment variables during CI/CD build.
(function () {
  const clientId = window.MSAL_CLIENT_ID || 'YOUR_CLIENT_ID';
  const tenantId = window.MSAL_TENANT_ID || 'common';

  if (clientId === 'YOUR_CLIENT_ID') {
    console.warn('[MSAL] No client ID configured – Microsoft Graph integration disabled.');
    window.msalInstance = null;
    window.msalAcquireToken = function () {
      return Promise.reject(new Error('MSAL not configured'));
    };
    return;
  }

  const msalConfig = {
    auth: {
      clientId: clientId,
      authority: 'https://login.microsoftonline.com/' + tenantId,
      redirectUri: window.location.origin,
    },
    cache: {
      cacheLocation: 'sessionStorage',
      storeAuthStateInCookie: false,
    },
  };

  window.msalInstance = new msal.PublicClientApplication(msalConfig);

  window.msalAcquireToken = async function (scope) {
    const accounts = window.msalInstance.getAllAccounts();
    const request = { scopes: [scope], account: accounts[0] };
    try {
      const result = await window.msalInstance.acquireTokenSilent(request);
      return result.accessToken;
    } catch (_) {
      const result = await window.msalInstance.acquireTokenPopup({ scopes: [scope] });
      return result.accessToken;
    }
  };
})();
