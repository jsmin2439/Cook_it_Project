module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    "ecmaVersion": 2018,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    // 1) 중괄호 안의 공백 허용
    "object-curly-spacing": ["error", "always"],

    // 2) 최대 줄 길이 제한 끄기
    "max-len": "off",

    // 3) JSDoc 주석 의무 끄기
    "require-jsdoc": "off",

    // 4) trailing comma를 강제하지 않음
    "comma-dangle": "off",
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", { "allowTemplateLiterals": true }],
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
