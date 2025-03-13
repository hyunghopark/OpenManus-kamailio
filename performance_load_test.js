import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Performance Test Configuration
export const options = {
    // Test Stages
    stages: [
        { duration: '2m', target: 100 },   // Ramp-up to 100 users
        { duration: '5m', target: 100 },   // Sustained load
        { duration: '2m', target: 200 },   // Spike to 200 users
        { duration: '2m', target: 0 }      // Ramp-down
    ],

    // Thresholds for performance metrics
    thresholds: {
        'http_req_duration': ['p(95)<500'],  // 95% of requests under 500ms
        'http_req_failed': ['rate<0.01'],    // Less than 1% request failure
        'sip_registration_rate': ['rate>0.99']  // 99% registration success
    },

    // Test Scenario Configuration
    scenarios: {
        sip_registration: {
            executor: 'ramping-arrival-rate',
            startRate: 10,
            timeUnit: '1s',
            preAllocatedVUs: 50,
            maxVUs: 250,
            stages: [
                { duration: '2m', target: 50 },
                { duration: '5m', target: 100 },
                { duration: '2m', target: 200 }
            ]
        }
    }
};

// Custom metric for SIP registration success rate
const registrationSuccessRate = new Rate('sip_registration_rate');

// SIP Registration Simulation Function
function simulateSIPRegistration() {
    // Generate unique user credentials
    const username = `user_${__ITER}`;
    const domain = 'kamailio.local';
    const password = generatePassword();

    // Construct SIP REGISTER request
    const registerRequest = {
        method: 'REGISTER',
        url: 'sip:kamailio.local',
        headers: {
            'Via': `SIP/2.0/UDP ${__ENV.VU_IP}:${5060};branch=z9hG4bK${generateBranch()}`,
            'From': `<sip:${username}@${domain}>;tag=${generateTag()}`,
            'To': `<sip:${username}@${domain}>`,
            'Call-ID': `${generateCallID()}`,
            'CSeq': '1 REGISTER',
            'Contact': `<sip:${username}@${__ENV.VU_IP}:${5060}>`,
            'Max-Forwards': '70',
            'Expires': '3600'
        }
    };

    // Send registration request
    const response = http.request(registerRequest.method, registerRequest.url, null, {
        headers: registerRequest.headers
    });

    // Validate registration response
    const registrationSuccessful = check(response, {
        'registration status is 200': (r) => r.status === 200,
        'response time is acceptable': (r) => r.timings.duration < 500
    });

    // Update custom metric
    registrationSuccessRate.add(registrationSuccessful);
}

// Utility Functions
function generatePassword(length = 12) {
    const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()';
    return Array.from(crypto.getRandomValues(new Uint32Array(length)))
        .map((x) => charset[x % charset.length])
        .join('');
}

function generateBranch() {
    return Math.random().toString(36).substring(2, 15);
}

function generateTag() {
    return Math.random().toString(36).substring(2, 15);
}

function generateCallID() {
    return `${Date.now()}@${Math.random().toString(36).substring(2, 15)}`;
}

// Test Scenarios
export default function() {
    group('SIP Registration Performance', () => {
        // Simulate SIP registration
        simulateSIPRegistration();

        // Think time between requests
        sleep(1);
    });

    group('Additional Performance Checks', () => {
        // Simulate other SIP-related operations
        // e.g., invite, message, etc.
        // Add more complex scenarios as needed
    });
}

// Teardown Function
export function teardown(data) {
    // Optional cleanup or final metrics reporting
    console.log('Performance Test Completed');
    console.log('Registration Success Rate:', registrationSuccessRate.rate);
}

// Performance Monitoring Hooks
export function handleSummary(data) {
    return {
        'performance_summary.json': JSON.stringify(data),
        'stdout': data.metrics.sip_registration_rate.toString()
    };
}