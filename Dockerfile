# syntax=docker/dockerfile:1

########## build stage ##########
FROM node:20-alpine AS builder
WORKDIR /app

# 仅拷贝依赖清单，最大化缓存命中
COPY package.json pnpm-lock.yaml ./

# pnpm 版本固定（与你项目一致）
RUN corepack enable && corepack prepare pnpm@9.14.4 --activate

# 安装依赖
RUN pnpm i --frozen-lockfile

# 再拷贝源码
COPY . .

# 构建产物（需要已配置 adapter: node({mode:"standalone"}) + output:"server"）
RUN --mount=type=secret,id=OAUTH_GITHUB_CLIENT_ID \
    --mount=type=secret,id=OAUTH_GITHUB_CLIENT_SECRET \
    export OAUTH_GITHUB_CLIENT_ID="$(cat /run/secrets/OAUTH_GITHUB_CLIENT_ID)" && \
    export OAUTH_GITHUB_CLIENT_SECRET="$(cat /run/secrets/OAUTH_GITHUB_CLIENT_SECRET)" && \
    pnpm build

########## runtime stage ##########
FROM node:20-alpine AS runtime
WORKDIR /app

ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=4321

# 只带运行所需文件（保守做法：包含 node_modules）
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist

EXPOSE 4321

# 生产运行入口（Astro Node standalone 的典型入口）
CMD ["node", "./dist/server/entry.mjs"]
