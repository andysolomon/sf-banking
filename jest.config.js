const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    // Keep Jest off the Vercel mock's plain JS (it isn't an LWC) — the todo-app learned
    // that sfdx-lwc-jest's default globs otherwise sweep non-LWC JS and crash under jsdom.
    testPathIgnorePatterns: ['/node_modules/', '/.git/', '/mock/'],
    modulePathIgnorePatterns: ['/mock/']
};
