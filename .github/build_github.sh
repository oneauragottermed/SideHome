# move lc to working folder
mv "$archive_path.xcarchive/Products/Applications" Payload

# SideStoreSupport is only used by the LiveContainer+SideStore build, which SideHome doesn't ship
rm -rf Payload/LiveContainer.app/Frameworks/SideStoreSupport.framework

zip -r "SideHome.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"
