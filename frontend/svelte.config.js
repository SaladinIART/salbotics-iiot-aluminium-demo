import adapter from '@sveltejs/adapter-static';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	kit: {
		adapter: adapter({
			pages: '../services/api/static',
			assets: '../services/api/static',
			fallback: 'index.html',
			precompress: false,
			strict: false,
		}),
	},
};

export default config;
