#import "bridge_policy.h"

BOOL CynaBridgeAllowed(WKScriptMessage *message) {
    return message.frameInfo.mainFrame &&
        [message.frameInfo.securityOrigin.protocol isEqualToString:@"cyna-app"] &&
        [message.frameInfo.securityOrigin.host isEqualToString:@"local"];
}
