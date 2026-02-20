// Microsoft Graph / MSAL configuration
// Client ID can be set via localStorage, environment variable, or hardcoded.
(function () {
  // Check if MSAL library is loaded
  if (typeof msal === 'undefined' || !msal.PublicClientApplication) {
    console.warn('[MSAL] MSAL library not loaded – Microsoft Graph integration disabled.');
    window.msalInstance = null;
    window.msalSetClientId = function (newClientId, newTenantId) {
      if (newClientId) localStorage.setItem('msal_client_id', newClientId);
      if (newTenantId) localStorage.setItem('msal_tenant_id', newTenantId);
      return true;
    };
    window.msalGetClientId = function () {
      return localStorage.getItem('msal_client_id');
    };
    window.msalClearClientId = function () {
      localStorage.removeItem('msal_client_id');
      localStorage.removeItem('msal_tenant_id');
      return true;
    };
    window.msalAcquireToken = function () { return Promise.reject(new Error('MSAL not loaded')); };
    window.msalLogin = function () { return Promise.reject(new Error('MSAL not loaded')); };
    window.msalLogout = function () { return Promise.resolve(); };
    window.msalGetAccount = function () { return null; };
    window.msalIsConfigured = function () { return false; };
    return;
  }

  // Priority: localStorage > window.MSAL_CLIENT_ID > 'YOUR_CLIENT_ID'
  const storedClientId = localStorage.getItem('msal_client_id');
  const storedTenantId = localStorage.getItem('msal_tenant_id');
  
  const clientId = storedClientId || window.MSAL_CLIENT_ID || 'YOUR_CLIENT_ID';
  const tenantId = storedTenantId || window.MSAL_TENANT_ID || 'common';

  // Function to set Client ID (requires page reload)
  window.msalSetClientId = function (newClientId, newTenantId) {
    if (newClientId) {
      localStorage.setItem('msal_client_id', newClientId);
    }
    if (newTenantId) {
      localStorage.setItem('msal_tenant_id', newTenantId);
    }
    return true;
  };

  // Function to get current Client ID
  window.msalGetClientId = function () {
    return clientId === 'YOUR_CLIENT_ID' ? null : clientId;
  };

  // Function to clear Client ID
  window.msalClearClientId = function () {
    localStorage.removeItem('msal_client_id');
    localStorage.removeItem('msal_tenant_id');
    return true;
  };

  if (clientId === 'YOUR_CLIENT_ID') {
    console.warn('[MSAL] No client ID configured – Microsoft Graph integration disabled.');
    window.msalInstance = null;
    window.msalAcquireToken = function () {
      return Promise.reject(new Error('MSAL not configured'));
    };
    window.msalLogin = function () {
      return Promise.reject(new Error('MSAL not configured'));
    };
    window.msalLogout = function () {
      return Promise.resolve();
    };
    window.msalGetAccount = function () {
      return null;
    };
    window.msalIsConfigured = function () {
      return false;
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

  try {
    window.msalInstance = new msal.PublicClientApplication(msalConfig);
  } catch (e) {
    console.error('[MSAL] Initialization failed:', e);
    // Clear invalid config and reload
    localStorage.removeItem('msal_client_id');
    localStorage.removeItem('msal_tenant_id');
    window.msalInstance = null;
    window.msalIsConfigured = function () { return false; };
    window.msalLogin = function () { return Promise.reject(e); };
    window.msalLogout = function () { return Promise.resolve(); };
    window.msalGetAccount = function () { return null; };
    window.msalAcquireToken = function () { return Promise.reject(e); };
    return;
  }

  window.msalIsConfigured = function () {
    return true;
  };

  window.msalGetAccount = function () {
    const accounts = window.msalInstance.getAllAccounts();
    if (accounts.length > 0) {
      return JSON.stringify({
        name: accounts[0].name || '',
        email: accounts[0].username || '',
      });
    }
    return null;
  };

  window.msalLogin = async function () {
    try {
      const result = await window.msalInstance.loginPopup({
        scopes: ['User.Read', 'Files.ReadWrite', 'Calendars.ReadWrite'],
      });
      return JSON.stringify({
        name: result.account.name || '',
        email: result.account.username || '',
      });
    } catch (e) {
      console.error('MSAL login failed:', e);
      throw e;
    }
  };

  window.msalLogout = async function () {
    const accounts = window.msalInstance.getAllAccounts();
    if (accounts.length > 0) {
      await window.msalInstance.logoutPopup({
        account: accounts[0],
      });
    }
  };

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
