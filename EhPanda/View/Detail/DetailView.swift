//
//  DetailView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/05.
//

import SwiftUI
import Kingfisher

struct DetailView: View, StoreAccessor, PersistenceAccessor {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) private var colorScheme

    @State private var keyword = ""
    @State private var isNavLinkActive = false

    let gid: String

    init(gid: String) {
        self.gid = gid
    }

    // MARK: DetailView
    var body: some View {
        ZStack {
            NavigationLink(
                "",
                destination: AssociatedView(
                    keyword: keyword
                ),
                isActive: $isNavLinkActive
            )
            if let detail = mangaDetail {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        HeaderView(
                            manga: manga, detail: detail,
                            translatesCategory: setting
                                .translatesCategory,
                            favoriteNames: user.favoriteNames,
                            addFavAction: addFavorite,
                            deleteFavAction: deleteFavorite,
                            onUploaderTapAction: onUploaderTap
                        )
                        DescScrollView(detail: detail)
                        ActionRow(
                            detail: detail,
                            ratingAction: onUserRatingChanged,
                            galleryAction: onSimilarGalleryTap
                        )
                        if !mangaState.tags.isEmpty {
                            TagsView(
                                tags: mangaState.tags,
                                onTapAction: onTagViewTap
                            )
                        }
                        PreviewView(
                            previews: mangaState.previews,
                            pageCount: detail.pageCount,
                            fetchAction: fetchMangaPreviews
                        )
                        CommentScrollView(
                            gid: gid,
                            comments: mangaState.comments,
                            toggleCommentAction: onCommentButtonTap
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    .padding(.top, -25)
                }
                .transition(opacityTransition)
            } else if detailInfo.mangaDetailLoading {
                LoadingView()
            } else if detailInfo.mangaDetailLoadFailed {
                NetworkErrorView(retryAction: fetchMangaDetail)
            }
        }
        .task(updateHistoryItems)
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .navigationBarHidden(environment.navBarHidden)
        .sheet(item: environmentBinding.detailViewSheetState) { item in
            Group {
                switch item {
                case .archive:
                    ArchiveView(gid: gid)
                case .torrents:
                    TorrentsView(gid: gid, token: manga.token)
                case .comment:
                    DraftCommentView(
                        content: commentContentBinding,
                        title: "Post Comment",
                        postAction: onCommentPost,
                        cancelAction: toggleSheetStateNil
                    )
                }
            }
            .accentColor(accentColor)
            .blur(radius: environment.blurRadius)
            .allowsHitTesting(environment.isAppUnlocked)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: onArchiveButtonTap) {
                        Label("Archive", systemImage: "doc.zipper")
                    }
                    .disabled(mangaDetail?.archiveURL == nil)
                    Button(action: onTorrentsButtonTap) {
                        Label(
                            "Torrents".localized() + (
                                mangaDetail?.torrentCount ?? 0 > 0
                                ? " (\(mangaDetail?.torrentCount ?? 0))" : ""
                            ),
                            systemImage: "leaf"
                        )
                    }
                    .disabled((mangaDetail?.torrentCount ?? 0 > 0) != true)
                    Button(action: onShareButtonTap) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .imageScale(.large)
                }
                .disabled(
                    mangaDetail == nil
                        || detailInfo.mangaDetailLoading
                        || detailInfo.mangaDetailUpdating
                )
            }
        }
    }
}

// MARK: Private Properties
private extension DetailView {
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }
    var detailInfoBinding: Binding<AppState.DetailInfo> {
        $store.appState.detailInfo
    }
    var commentContent: String {
        detailInfo.commentContent
    }
    var commentContentBinding: Binding<String> {
        detailInfoBinding.commentContent
    }
}

// MARK: Private Methods
private extension DetailView {
    func onAppear() {
        if environment.navBarHidden {
            store.dispatch(.toggleNavBar(hidden: false))
        }

        fetchMangaDetail()
        updateViewControllersCount()
    }
    func onDisappear() {
        updateViewControllersCount()
        postDetailViewOnDisappearNotification()
    }
    func onArchiveButtonTap() {
        toggleSheet(state: .archive)
    }
    func onTorrentsButtonTap() {
        toggleSheet(state: .torrents)
    }
    func onCommentButtonTap() {
        toggleSheet(state: .comment)
    }
    func onShareButtonTap() {
        guard let data = URL(string: manga.detailURL) else { return }
        presentActivityVC(items: [data])
    }
    func onUserRatingChanged(value: Int) {
        store.dispatch(.rate(gid: gid, rating: value))
    }
    func navigateToAssociatedGallery(_ keyword: String? = nil) {
        guard let keyword = keyword else { return }

        self.keyword = keyword
        isNavLinkActive.toggle()

    }
    func onUploaderTap() {
        guard let uploader = mangaDetail?.uploader else { return }
        navigateToAssociatedGallery("uploader:" + "\"\(uploader)\"$")
    }
    func onSimilarGalleryTap() {
        navigateToAssociatedGallery(mangaDetail?.title.trimmedTitle())
    }
    func onTagViewTap(keyword: String) {
        navigateToAssociatedGallery(keyword + "$")
    }
    func onCommentPost() {
        store.dispatch(.comment(gid: gid, content: commentContent))
        store.dispatch(.clearDetailViewCommentContent)
        toggleSheetStateNil()
    }
    func toggleSheet(state: DetailViewSheetState?) {
        store.dispatch(.toggleDetailViewSheet(state: state))
    }
    func toggleSheetStateNil() {
        toggleSheet(state: nil)
    }

    func addFavorite(index: Int) {
        store.dispatch(.addFavorite(gid: manga.gid, favIndex: index))
    }
    func deleteFavorite() {
        store.dispatch(.deleteFavorite(gid: manga.gid))
    }
    func updateViewControllersCount() {
        store.dispatch(.updateViewControllersCount)
    }
    func fetchMangaDetail() {
        store.dispatch(.fetchMangaDetail(gid: gid))
    }
    func fetchMangaPreviews(index: Int) {
        store.dispatch(.fetchMangaPreviews(gid: gid, index: index))
    }
    func updateHistoryItems() {
        if environment.homeListType != .history {
            PersistenceController.updateLastOpenDate(gid: gid)
        }
    }
}

// MARK: HeaderView
private struct HeaderView: View {
    private let manga: Manga
    private let detail: MangaDetail
    private let translatesCategory: Bool
    private let favoriteNames: [Int: String]?
    private let addFavAction: (Int) -> Void
    private let deleteFavAction: () -> Void
    private let onUploaderTapAction: () -> Void

    init(
        manga: Manga,
        detail: MangaDetail,
        translatesCategory: Bool,
        favoriteNames: [Int: String]?,
        addFavAction: @escaping (Int) -> Void,
        deleteFavAction: @escaping () -> Void,
        onUploaderTapAction: @escaping () -> Void
    ) {
        self.manga = manga
        self.detail = detail
        self.translatesCategory = translatesCategory
        self.favoriteNames = favoriteNames
        self.addFavAction = addFavAction
        self.deleteFavAction = deleteFavAction
        self.onUploaderTapAction = onUploaderTapAction
    }

    var body: some View {
        HStack {
            KFImage(URL(string: manga.coverURL))
                .placeholder {
                    Placeholder(style: .activity(
                        ratio: Defaults.ImageSize
                            .headerScale
                    ))
                }
                .defaultModifier()
                .scaledToFit()
                .frame(width: width, height: height)
            VStack(alignment: .leading) {
                Text(title)
                    .fontWeight(.bold)
                    .lineLimit(3)
                    .font(.title3)
                Button(
                    manga.uploader ?? "",
                    action: onUploaderTapAction
                )
                .lineLimit(1)
                .font(.callout)
                .foregroundStyle(.secondary)
                Spacer()
                HStack {
                    Text(category)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .foregroundColor(manga.color)
                        )
                    Spacer()
                    ZStack {
                        Button(action: deleteFavAction) {
                            Image(systemName: "heart.fill")
                                .imageScale(.large)
                                .foregroundStyle(.tint)
                        }
                        .opacity(detail.isFavored ? 1 : 0)
                        Menu {
                            ForEach(0..<(favoriteNames?.count ?? 10) - 1) { index in
                                Button(
                                    User.getFavNameFrom(
                                        index: index,
                                        names: favoriteNames
                                    )
                                ) {
                                    addFavAction(index)
                                }
                            }
                        } label: {
                            Image(systemName: "heart")
                                .imageScale(.large)
                                .foregroundStyle(.tint)
                        }
                        .opacity(detail.isFavored ? 0 : 1)
                    }
                    Button(action: {}, label: {
                        NavigationLink(destination: ContentView(gid: manga.gid)) {
                            Text("Read".localized().uppercased())
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.vertical, -2)
                                .padding(.horizontal, 2)
                        }
                    })
                    .buttonStyle(.bordered)
                    .controlProminence(.increased)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: height)
        }
    }
}

private extension HeaderView {
    var width: CGFloat {
        Defaults.ImageSize.headerW
    }
    var height: CGFloat {
        Defaults.ImageSize.headerH
    }
    var title: String {
        if let jpnTitle = detail.jpnTitle {
            return jpnTitle
        } else {
            return detail.title
        }
    }
    var category: String {
        if translatesCategory {
            return manga.category.rawValue.localized()
        } else {
            return manga.category.rawValue
        }
    }
}

// MARK: DescScrollView
private struct DescScrollView: View {
    @State private var itemWidth = max(absWindowW / 5, 80)

    private let detail: MangaDetail

    init(detail: MangaDetail) {
        self.detail = detail
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center) {
                DescScrollItem(
                    title: "Favored",
                    value: detail.likeCount,
                    numeral: "Times"
                )
                .frame(width: itemWidth)
                Divider()
                DescScrollItem(
                    title: "Language",
                    value: detail.languageAbbr,
                    numeral: detail.language.rawValue
                )
                .frame(width: itemWidth)
                Divider()
                DescScrollRatingItem(
                    title: String(detail.ratingCount)
                        + " Ratings".localized(),
                    rating: detail.rating
                )
                .frame(width: itemWidth)
                Divider()
                DescScrollItem(
                    title: "Page Count",
                    value: detail.pageCount,
                    numeral: "Pages"
                )
                .frame(width: itemWidth)
                Divider()
                DescScrollItem(
                    title: "Size",
                    value: String(detail.sizeCount),
                    numeral: detail.sizeType
                )
                .frame(width: itemWidth)
            }
            .drawingGroup()
        }
        .frame(height: 60)
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("AppWidthDidChange")
            )
        ) { _ in
            onWidthChange()
        }
    }

    private func onWidthChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if itemWidth != max(absWindowW / 5, 80) {
                withAnimation {
                    itemWidth = max(absWindowW / 5, 80)
                }
            }
        }
    }
}

private struct DescScrollItem: View {
    private let title: String
    private let value: String
    private let numeral: String

    init(title: String, value: String, numeral: String) {
        self.title = title
        self.value = value
        self.numeral = numeral
    }

    init(title: String, value: Int, numeral: String) {
        self.title = title
        self.value = String(value)
        self.numeral = numeral
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(title.localized().uppercased())
                .font(.caption)
            Text(value)
                .fontWeight(.medium)
                .font(.title3)
                .lineLimit(1)
            Text(numeral.localized())
                .font(.caption)
        }
    }
}

private struct DescScrollRatingItem: View {
    private let title: String
    private let rating: Float

    init(title: String, rating: Float) {
        self.title = title
        self.rating = rating
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(title.localized().uppercased())
                .font(.caption)
                .lineLimit(1)
            Text(String(format: "%.2f", rating))
                .fontWeight(.medium)
                .font(.title3)
            RatingView(rating: rating)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: ActionRow
private struct ActionRow: View {
    @State private var showUserRating = false
    @State private var userRating: Int = 0

    private let detail: MangaDetail
    private let ratingAction: (Int) -> Void
    private let galleryAction: () -> Void

    init(
        detail: MangaDetail,
        ratingAction: @escaping (Int) -> Void,
        galleryAction: @escaping () -> Void
    ) {
        self.detail = detail
        self.ratingAction = ratingAction
        self.galleryAction = galleryAction
    }

    var body: some View {
        VStack {
            HStack {
                Group {
                    Button(action: onRateButtonTap) {
                        Spacer()
                        Image(systemName: "square.and.pencil")
                        Text("Give a Rating")
                            .fontWeight(.bold)
                        Spacer()
                    }
                    Button(action: galleryAction) {
                        Spacer()
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Similar Gallery")
                            .fontWeight(.bold)
                        Spacer()
                    }
                }
                .font(.callout)
                .foregroundStyle(.primary)
            }
            if showUserRating {
                HStack {
                    RatingView(rating: Float(userRating) / 2)
                        .font(.system(size: 24))
                        .foregroundStyle(.yellow)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged(onRatingChanged)
                                .onEnded(onRatingEnded)
                        )
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal)
        .task(onStartTasks)
    }
}

private extension ActionRow {
    func onStartTasks() {
        userRating = Int(detail.userRating.fixedRating() * 2)
    }
    func onRateButtonTap() {
        withAnimation {
            showUserRating.toggle()
        }
    }
    func onRatingChanged(value: DragGesture.Value) {
        updateRating(value: value)
    }
    func onRatingEnded(value: DragGesture.Value) {
        updateRating(value: value)
        ratingAction(userRating)
        impactFeedback(style: .soft)
        withAnimation(Animation.default.delay(1)) {
            showUserRating.toggle()
        }
    }
    func updateRating(value: DragGesture.Value) {
        let rating = Int(value.location.x / 31 * 2) + 1
        userRating = min(max(rating, 1), 10)
    }
}

// MARK: TagsView
private struct TagsView: View {
    private let tags: [MangaTag]
    private let onTapAction: (String) -> Void

    init(
        tags: [MangaTag],
        onTapAction: @escaping (String) -> Void
    ) {
        self.tags = tags
        self.onTapAction = onTapAction
    }

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(tags) { tag in
                TagRow(tag: tag, onTapAction: onTapAction)
            }
        }
        .padding(.horizontal)
    }
}

private struct TagRow: View {
    @Environment(\.colorScheme) private var colorScheme

    private let tag: MangaTag
    private let onTapAction: (String) -> Void
    private var reversePrimary: Color {
        colorScheme == .light ? .white : .black
    }

    init(
        tag: MangaTag,
        onTapAction: @escaping (String) -> Void
    ) {
        self.tag = tag
        self.onTapAction = onTapAction
    }

    var body: some View {
        HStack(alignment: .top) {
            Text(tag.category.rawValue.localized())
                .fontWeight(.bold)
                .font(.subheadline)
                .foregroundColor(reversePrimary)
                .padding(.vertical, 5)
                .padding(.horizontal, 14)
                .background(
                    Rectangle()
                        .foregroundColor(Color(.systemGray))
                )
                .cornerRadius(5)
            TagCloudView(
                tag: tag,
                font: .subheadline,
                textColor: .primary,
                backgroundColor: Color(.systemGray5),
                paddingV: 5, paddingH: 14,
                onTapAction: onTapAction
            )
        }
    }
}

// MARK: PreviewView
private struct PreviewView: View {
    private let previews: [Int: String]
    private let pageCount: Int
    private let fetchAction: (Int) -> Void

    init(
        previews: [Int: String],
        pageCount: Int,
        fetchAction: @escaping (Int) -> Void
    ) {
        self.previews = previews
        self.pageCount = pageCount
        self.fetchAction = fetchAction
    }

    private var width: CGFloat {
        Defaults.ImageSize.previewAvgW
    }
    private var height: CGFloat {
        width / Defaults.ImageSize.previewScale
    }

    var body: some View {
        VStack {
            HStack {
                Text("Preview")
                    .fontWeight(.bold)
                    .font(.title3)
                Spacer()
                NavigationLink(
                    destination: MorePreviewView(
                        previews: previews,
                        pageCount: pageCount,
                        fetchAction: fetchAction
                    )
                ) {
                    Text("Show All")
                        .font(.subheadline)
                }
                .opacity(pageCount > 20 ? 1 : 0)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(1..<min(pageCount, 20)) { index in
                        let (url, modifier) = getPreviewConfigs(
                            previews: previews, index: index
                        )
                        KFImage(URL(string: url))
                            .placeholder {
                                Placeholder(style: .activity(
                                    ratio: Defaults.ImageSize
                                        .previewScale
                                ))
                            }
                            .imageModifier(modifier)
                            .fade(duration: 0.25)
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: width,
                                height: height
                            )
                    }
                }
            }
        }
    }
}

// MARK: MorePreviewView
private struct MorePreviewView: View {
    private let previews: [Int: String]
    private let pageCount: Int
    private let fetchAction: (Int) -> Void

    init(
        previews: [Int: String],
        pageCount: Int,
        fetchAction: @escaping (Int) -> Void
    ) {
        self.previews = previews
        self.pageCount = pageCount
        self.fetchAction = fetchAction
    }

    private var gridItems: [GridItem] {
        [GridItem(
            .adaptive(
                minimum: Defaults.ImageSize.previewMinW,
                maximum: Defaults.ImageSize.previewMaxW
            ),
            spacing: 10
        )]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridItems) {
                ForEach(1..<pageCount + 1) { index in
                    VStack {
                        let (url, modifier) = getPreviewConfigs(
                            previews: previews, index: index
                        )
                        KFImage(URL(string: url))
                            .placeholder {
                                Placeholder(style: .activity(
                                    ratio: Defaults.ImageSize
                                        .previewScale
                                ))
                            }
                            .imageModifier(modifier)
                            .fade(duration: 0.25)
                            .resizable()
                            .scaledToFit()
                        Text("\(index)")
                            .font(isPadWidth ? .callout : .caption)
                            .foregroundColor(.secondary)
                    }
                    .onAppear {
                        onImageAppear(index: index)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private func onImageAppear(index: Int) {
        if previews[index] == nil && (index - 1) % 20 == 0 {
            fetchAction(index)
        }
    }
}

private func getPreviewConfigs(
    previews: [Int: String], index: Int
) -> (String, ImageModifier) {
    let originalURL = previews[index] ?? ""
    let configs = Parser.parsePreviewConfigs(
        string: originalURL
    )
    let containsConfigs = configs != nil

    let plainURL = configs?.0 ?? ""
    let loadURL = containsConfigs
        ? plainURL : originalURL
    let modifier = RoundedOffsetModifier(
        size: configs?.1, offset: configs?.2
    )
    return (loadURL, modifier)
}

// MARK: CommentScrollView
private struct CommentScrollView: View {
    private let gid: String
    private let comments: [MangaComment]
    private let toggleCommentAction: () -> Void

    init(
        gid: String,
        comments: [MangaComment],
        toggleCommentAction: @escaping () -> Void
    ) {
        self.gid = gid
        self.comments = comments
        self.toggleCommentAction = toggleCommentAction
    }

    var body: some View {
        VStack {
            HStack {
                Text("Comment")
                    .fontWeight(.bold)
                    .font(.title3)
                Spacer()
                NavigationLink(
                    destination: CommentView(
                        gid: gid, comments: comments
                    )
                ) {
                    Text("Show All")
                        .font(.subheadline)
                }
                .opacity(comments.isEmpty ? 0 : 1)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(comments.prefix(6)) { comment in
                        CommentScrollCell(comment: comment)
                    }
                }
                .drawingGroup()
            }
            CommentButton(action: toggleCommentAction)
        }
    }
}

private struct CommentScrollCell: View {
    private let comment: MangaComment
    private var content: String {
        comment.contents
            .filter {
                [.plainText, .linkedText]
                    .contains($0.type)
            }
            .compactMap {
                $0.text
            }
            .joined()
    }

    init(comment: MangaComment) {
        self.comment = comment
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(comment.author)
                    .fontWeight(.bold)
                    .font(.subheadline)
                Spacer()
                Group {
                    ZStack {
                        Image(systemName: "hand.thumbsup.fill")
                            .opacity(comment.votedUp ? 1 : 0)
                        Image(systemName: "hand.thumbsdown.fill")
                            .opacity(comment.votedDown ? 1 : 0)
                    }
                    Text(comment.score ?? "")
                    Text(comment.formattedDateString)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            Text(content)
                .padding(.top, 1)
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .frame(width: 300, height: 120)
        .cornerRadius(15)
    }
}

// MARK: Definition
enum DetailViewSheetState: Identifiable {
    var id: Int { hashValue }

    case archive
    case torrents
    case comment
}
