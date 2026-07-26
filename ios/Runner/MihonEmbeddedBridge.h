#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^MangatanEmbeddedMihonStartCompletion)(
    int32_t port,
    NSError *_Nullable error);
typedef void (^MangatanEmbeddedMihonCompletion)(NSError *_Nullable error);
typedef void (^MangatanEmbeddedMihonStatusCompletion)(
    BOOL isRunning,
    NSError *_Nullable error);

FOUNDATION_EXPORT void MangatanEmbeddedMihonStart(
    int32_t port,
    MangatanEmbeddedMihonStartCompletion completion);
FOUNDATION_EXPORT void MangatanEmbeddedMihonStop(
    MangatanEmbeddedMihonCompletion completion);
FOUNDATION_EXPORT void MangatanEmbeddedMihonIsRunning(
    MangatanEmbeddedMihonStatusCompletion completion);

NS_ASSUME_NONNULL_END
