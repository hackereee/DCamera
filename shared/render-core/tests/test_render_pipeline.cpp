#include "scamera/render/render_pipeline.h"
#include <cstring>

static int failures = 0;
#define ASSERT(expr) do { if (!(expr)) { failures++; } } while(0)

int main() {
    using namespace scamera;

    // 未配置时 submitFrame 应失败
    {
        RenderPipeline p;
        char dummy = 1;
        ASSERT(!p.submitFrame(&dummy, 100));
    }

    // 配置预览后可提交帧
    {
        RenderPipeline p;
        ASSERT(p.configurePreview(1280, 720));
        char dummy = 1;
        ASSERT(p.submitFrame(&dummy, 100));
    }

    // 无效尺寸配置失败
    {
        RenderPipeline p;
        ASSERT(!p.configurePreview(0, 720));
        ASSERT(!p.configurePreview(1280, -1));
    }

    // 帧队列有界（上限 3），超出时丢帧
    {
        RenderPipeline p;
        p.configurePreview(1280, 720);
        p.configureOffscreen(1920, 1080);
        char data[4] = {1, 2, 3, 4};
        ASSERT(p.submitFrame(data, 1));
        ASSERT(p.submitFrame(data, 2));
        ASSERT(p.submitFrame(data, 3));
        ASSERT(!p.submitFrame(data, 4)); // 队列满，丢帧

        // 消费一帧后可再提交
        auto frame = p.consumeOffscreenFrame();
        ASSERT(frame.timestampNs == 1);
        ASSERT(frame.data != nullptr);
        ASSERT(p.submitFrame(data, 5)); // 有空位了
    }

    // 未配置离屏时 consumeOffscreenFrame 返回空
    {
        RenderPipeline p;
        p.configurePreview(1280, 720);
        char dummy = 1;
        p.submitFrame(&dummy, 100);
        auto frame = p.consumeOffscreenFrame();
        ASSERT(frame.data == nullptr);
    }

    // release 后无法提交
    {
        RenderPipeline p;
        p.configurePreview(1280, 720);
        p.release();
        char dummy = 1;
        ASSERT(!p.submitFrame(&dummy, 100));
    }

    return failures;
}
