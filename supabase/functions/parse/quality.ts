/**
 * Quality Gate
 * 
 * Evaluates parsed content quality and determines appropriate fallback:
 * - Cookie consent wall detection
 * - Paywall detection
 * - Login/auth wall detection
 * - Minimum content threshold
 * - Encoding quality check
 * - Content confidence scoring
 */

// =============================================================================
// CONFIGURATION
// =============================================================================

const CONFIG = {
  // Minimum content length for valid article
  MIN_CONTENT_LENGTH: 300,
  
  // Cookie consent detection
  CONSENT_MAX_LENGTH: 600,
  CONSENT_MIN_KEYWORDS: 2,
  
  // Paywall detection
  PAYWALL_CONTENT_THRESHOLD: 500,
  
  // Encoding quality
  MAX_REPLACEMENT_CHAR_RATIO: 0.05,
};

// =============================================================================
// KEYWORD LISTS
// =============================================================================

const CONSENT_KEYWORDS = {
  en: [
    'cookie', 'cookies', 'consent', 'privacy policy', 'accept all',
    'we use cookies', 'gdpr', 'manage preferences', 'cookie settings',
    'by continuing', 'agree to our', 'accept cookies', 'reject all',
    'necessary cookies', 'functional cookies', 'analytics cookies',
    'personalization', 'we value your privacy', 'cookie notice'
  ],
  tr: [
    'çerez', 'çerezler', 'gizlilik politikası', 'kabul et', 'kabul ediyorum',
    'kvkk', 'kişisel veri', 'çerez politikası', 'çerez ayarları',
    'devam ederek', 'tümünü kabul', 'tümünü reddet', 'tercihler'
  ],
  de: [
    'cookies', 'datenschutz', 'akzeptieren', 'cookies akzeptieren',
    'einwilligung', 'datenschutzerklärung', 'alle akzeptieren',
    'notwendige cookies', 'einstellungen'
  ],
  fr: [
    'cookies', 'confidentialité', 'accepter', 'politique de confidentialité',
    'consentement', 'accepter tout', 'paramètres des cookies',
    'nous utilisons des cookies'
  ],
  es: [
    'cookies', 'privacidad', 'aceptar', 'política de privacidad',
    'aceptar todas', 'configuración de cookies', 'consentimiento'
  ]
};

const PAYWALL_KEYWORDS = [
  // English
  'subscribe to continue', 'subscriber-only', 'premium content',
  'members only', 'member-only', 'exclusive content', 'unlock this article',
  'sign up to read', 'create a free account', 'already a subscriber',
  'subscription required', 'paid subscribers', 'support quality journalism',
  'become a member', 'join to unlock', 'this content is for',
  'metered paywall', 'free articles remaining', 'you have read',
  'register to continue', 'sign in to read',
  
  // Turkish
  'abone ol', 'abonelik gerekli', 'premium içerik', 'sadece üyelere',
  'üye girişi', 'giriş yapın', 'ücretsiz kayıt',
  
  // German
  'premium-inhalt', 'nur für abonnenten', 'jetzt abonnieren',
  
  // French
  'réservé aux abonnés', 'contenu premium', 'abonnez-vous'
];

const LOGIN_KEYWORDS = [
  // English
  'sign in', 'log in', 'login', 'sign up', 'register', 'create account',
  'authentication required', 'please log in', 'session expired',
  'unauthorized', 'access denied', 'forbidden',
  
  // Turkish
  'giriş yap', 'kayıt ol', 'oturum aç', 'hesap oluştur',
  
  // German
  'anmelden', 'registrieren', 'einloggen',
  
  // French
  'se connecter', 'créer un compte', 'inscription'
];

const BLOCKED_CONTENT_PATTERNS = [
  // Captcha
  /recaptcha|hcaptcha|captcha/i,
  /verify you are human/i,
  /are you a robot/i,
  
  // JavaScript required
  /javascript is required/i,
  /please enable javascript/i,
  /this page requires javascript/i,
  
  // Bot detection
  /access denied/i,
  /blocked|forbidden/i,
  /rate limit exceeded/i,
  
  // Error pages
  /404 not found/i,
  /page not found/i,
  /error occurred/i,
  /something went wrong/i
];

// =============================================================================
// TYPES
// =============================================================================

export interface QualityCheckResult {
  isValid: boolean;
  confidence: number;          // 0.0 - 1.0
  issues: QualityIssue[];
  recommendation: QualityRecommendation;
  detectedWalls: {
    consent: boolean;
    paywall: boolean;
    login: boolean;
    captcha: boolean;
  };
}

export type QualityIssue = 
  | 'CONTENT_TOO_SHORT'
  | 'CONSENT_WALL'
  | 'PAYWALL'
  | 'LOGIN_REQUIRED'
  | 'CAPTCHA_DETECTED'
  | 'JAVASCRIPT_REQUIRED'
  | 'ENCODING_ISSUES'
  | 'BOT_BLOCKED'
  | 'ERROR_PAGE'
  | 'NO_CONTENT';

export type QualityRecommendation = 
  | 'ARTICLE'      // Good quality, serve as article
  | 'WEBVIEW'      // Show in webview
  | 'META_ONLY'    // Only show metadata card
  | 'RETRY'        // Temporary issue, retry later
  | 'REJECT';      // Don't process

export interface QualityOptions {
  minContentLength?: number;
  checkConsent?: boolean;
  checkPaywall?: boolean;
  strictMode?: boolean;
}

// =============================================================================
// MAIN QUALITY CHECK
// =============================================================================

export function checkContentQuality(
  html: string,
  extractedText: string,
  options: QualityOptions = {}
): QualityCheckResult {
  const {
    minContentLength = CONFIG.MIN_CONTENT_LENGTH,
    checkConsent = true,
    checkPaywall = true,
    strictMode = false
  } = options;
  
  const issues: QualityIssue[] = [];
  const detectedWalls = {
    consent: false,
    paywall: false,
    login: false,
    captcha: false
  };
  
  const textLength = extractedText.length;
  const lowerText = extractedText.toLowerCase();
  const lowerHtml = html.toLowerCase();
  
  // 1. Check for empty/no content
  if (textLength < 50) {
    issues.push('NO_CONTENT');
    return {
      isValid: false,
      confidence: 0,
      issues,
      recommendation: 'WEBVIEW',
      detectedWalls
    };
  }
  
  // 2. Check for consent wall
  if (checkConsent && textLength < CONFIG.CONSENT_MAX_LENGTH) {
    const consentKeywordCount = countKeywords(lowerText, getAllConsentKeywords());
    if (consentKeywordCount >= CONFIG.CONSENT_MIN_KEYWORDS) {
      detectedWalls.consent = true;
      issues.push('CONSENT_WALL');
    }
  }
  
  // 3. Check for paywall
  if (checkPaywall) {
    const paywallScore = calculatePaywallScore(lowerText, lowerHtml, textLength);
    if (paywallScore > 0.6) {
      detectedWalls.paywall = true;
      issues.push('PAYWALL');
    }
  }
  
  // 4. Check for login wall
  const loginScore = calculateLoginScore(lowerText, lowerHtml);
  if (loginScore > 0.5) {
    detectedWalls.login = true;
    issues.push('LOGIN_REQUIRED');
  }
  
  // 5. Check for captcha/bot detection
  for (const pattern of BLOCKED_CONTENT_PATTERNS) {
    if (pattern.test(extractedText) || pattern.test(html)) {
      if (/captcha|robot|human/i.test(pattern.source)) {
        detectedWalls.captcha = true;
        issues.push('CAPTCHA_DETECTED');
      } else if (/javascript/i.test(pattern.source)) {
        issues.push('JAVASCRIPT_REQUIRED');
      } else if (/denied|blocked|forbidden|rate/i.test(pattern.source)) {
        issues.push('BOT_BLOCKED');
      } else if (/404|error|wrong/i.test(pattern.source)) {
        issues.push('ERROR_PAGE');
      }
      break; // One pattern match is enough
    }
  }
  
  // 6. Check content length
  if (textLength < minContentLength && issues.length === 0) {
    issues.push('CONTENT_TOO_SHORT');
  }
  
  // 7. Check encoding quality
  const replacementCharCount = (extractedText.match(/\uFFFD/g) || []).length;
  const replacementRatio = replacementCharCount / textLength;
  if (replacementRatio > CONFIG.MAX_REPLACEMENT_CHAR_RATIO) {
    issues.push('ENCODING_ISSUES');
  }
  
  // Calculate confidence and recommendation
  const confidence = calculateConfidence(textLength, issues, detectedWalls);
  const recommendation = determineRecommendation(issues, detectedWalls, confidence, strictMode);
  
  return {
    isValid: issues.length === 0,
    confidence,
    issues,
    recommendation,
    detectedWalls
  };
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

function getAllConsentKeywords(): string[] {
  return Object.values(CONSENT_KEYWORDS).flat();
}

function countKeywords(text: string, keywords: string[]): number {
  let count = 0;
  for (const keyword of keywords) {
    if (text.includes(keyword.toLowerCase())) {
      count++;
    }
  }
  return count;
}

function calculatePaywallScore(text: string, html: string, textLength: number): number {
  let score = 0;
  let keywordMatches = 0;
  
  for (const keyword of PAYWALL_KEYWORDS) {
    if (text.includes(keyword.toLowerCase())) {
      keywordMatches++;
    }
  }
  
  // More keywords = higher score
  score += Math.min(keywordMatches * 0.15, 0.6);
  
  // Short content + paywall keywords = high score
  if (textLength < CONFIG.PAYWALL_CONTENT_THRESHOLD && keywordMatches > 0) {
    score += 0.3;
  }
  
  // Check for paywall meta tags
  if (html.includes('paywall') || html.includes('premium-content') || 
      html.includes('subscriber-only') || html.includes('metered')) {
    score += 0.2;
  }
  
  // Check for specific paywall HTML structures
  if (html.includes('class="paywall"') || html.includes('id="paywall"') ||
      html.includes('data-paywall') || html.includes('data-metered')) {
    score += 0.3;
  }
  
  return Math.min(score, 1.0);
}

function calculateLoginScore(text: string, html: string): number {
  let score = 0;
  let keywordMatches = 0;
  
  for (const keyword of LOGIN_KEYWORDS) {
    if (text.includes(keyword.toLowerCase())) {
      keywordMatches++;
    }
  }
  
  score += Math.min(keywordMatches * 0.1, 0.4);
  
  // Check for login forms
  if (html.includes('type="password"') || html.includes("type='password'")) {
    score += 0.3;
  }
  
  // Check for login-related classes/IDs
  if (html.includes('login-form') || html.includes('signin-form') ||
      html.includes('auth-form') || html.includes('login-modal')) {
    score += 0.2;
  }
  
  // Check for OAuth buttons
  if (html.includes('oauth') || html.includes('social-login') ||
      html.includes('google-sign-in') || html.includes('facebook-login')) {
    score += 0.1;
  }
  
  return Math.min(score, 1.0);
}

function calculateConfidence(
  textLength: number, 
  issues: QualityIssue[], 
  walls: QualityCheckResult['detectedWalls']
): number {
  let confidence = 1.0;
  
  // Reduce confidence based on content length
  if (textLength < 500) {
    confidence -= 0.2;
  } else if (textLength < 1000) {
    confidence -= 0.1;
  }
  
  // Reduce confidence for each issue
  for (const issue of issues) {
    switch (issue) {
      case 'NO_CONTENT':
        confidence -= 0.9;
        break;
      case 'CONSENT_WALL':
      case 'CAPTCHA_DETECTED':
        confidence -= 0.8;
        break;
      case 'PAYWALL':
      case 'LOGIN_REQUIRED':
        confidence -= 0.6;
        break;
      case 'JAVASCRIPT_REQUIRED':
      case 'BOT_BLOCKED':
        confidence -= 0.7;
        break;
      case 'ERROR_PAGE':
        confidence -= 0.9;
        break;
      case 'CONTENT_TOO_SHORT':
        confidence -= 0.3;
        break;
      case 'ENCODING_ISSUES':
        confidence -= 0.4;
        break;
    }
  }
  
  return Math.max(0, Math.min(confidence, 1.0));
}

function determineRecommendation(
  issues: QualityIssue[],
  walls: QualityCheckResult['detectedWalls'],
  confidence: number,
  strictMode: boolean
): QualityRecommendation {
  // Critical issues - reject or webview
  if (issues.includes('ERROR_PAGE')) {
    return 'REJECT';
  }
  
  if (issues.includes('NO_CONTENT') || issues.includes('CAPTCHA_DETECTED')) {
    return 'WEBVIEW';
  }
  
  if (walls.consent || walls.login) {
    return 'WEBVIEW';
  }
  
  if (walls.paywall) {
    return strictMode ? 'META_ONLY' : 'WEBVIEW';
  }
  
  if (issues.includes('BOT_BLOCKED') || issues.includes('JAVASCRIPT_REQUIRED')) {
    return 'WEBVIEW';
  }
  
  if (issues.includes('ENCODING_ISSUES')) {
    return 'WEBVIEW';
  }
  
  // Content quality issues
  if (issues.includes('CONTENT_TOO_SHORT')) {
    return confidence > 0.5 ? 'META_ONLY' : 'WEBVIEW';
  }
  
  // Good content
  if (confidence >= 0.7) {
    return 'ARTICLE';
  }
  
  if (confidence >= 0.4) {
    return 'META_ONLY';
  }
  
  return 'WEBVIEW';
}

// =============================================================================
// SPECIFIC DETECTORS
// =============================================================================

/**
 * Check if content looks like a Medium/Substack paywall
 */
export function detectMediumPaywall(html: string, textLength: number): boolean {
  const indicators = [
    'member-only story',
    'become a member',
    'metered-paywall',
    'meteredContent',
    'locked-content',
    'hi.postContent', // Medium's locked content
    'Read more from',
    'Open in app'
  ];
  
  const lowerHtml = html.toLowerCase();
  let matchCount = 0;
  
  for (const indicator of indicators) {
    if (lowerHtml.includes(indicator.toLowerCase())) {
      matchCount++;
    }
  }
  
  // Short content + indicators = paywall
  return matchCount >= 2 || (textLength < 500 && matchCount >= 1);
}

/**
 * Check if content looks like a Substack paywall
 */
export function detectSubstackPaywall(html: string, textLength: number): boolean {
  const indicators = [
    'paywall',
    'subscription-required',
    'subscribe to continue',
    'paid subscribers',
    'this post is for paid subscribers',
    'upgrade to paid'
  ];
  
  const lowerHtml = html.toLowerCase();
  let matchCount = 0;
  
  for (const indicator of indicators) {
    if (lowerHtml.includes(indicator.toLowerCase())) {
      matchCount++;
    }
  }
  
  return matchCount >= 1 || (textLength < 300 && html.includes('substack'));
}

/**
 * Quick check for obvious login redirects
 */
export function isLoginRedirect(url: string, finalUrl: string): boolean {
  const loginPatterns = [
    /\/login/i,
    /\/signin/i,
    /\/sign-in/i,
    /\/auth/i,
    /\/authenticate/i,
    /\/sso/i,
    /accounts\.google/i,
    /login\.microsoft/i,
    /facebook\.com\/login/i,
    /github\.com\/login/i
  ];
  
  // Check if redirected to a login page
  if (url !== finalUrl) {
    for (const pattern of loginPatterns) {
      if (pattern.test(finalUrl) && !pattern.test(url)) {
        return true;
      }
    }
  }
  
  return false;
}
