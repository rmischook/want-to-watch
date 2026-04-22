//
//  OnboardingView.swift
//  WantToWatch
//
//  Created by RICHARD MISCHOOK on 22/04/2026.
//

import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct OnboardingView: View {
    let onComplete: () -> Void
    
    @State private var currentPage = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "film.stack",
            title: "Your Watchlist, Your Way",
            description: "Manage movies and TV shows you want to watch, are currently watching, or have already finished."
        ),
        OnboardingPage(
            icon: "magnifyingglass",
            title: "Search TMDB",
            description: "Search The Movie Database for comprehensive information about any movie or TV show."
        ),
        OnboardingPage(
            icon: "square.and.arrow.up",
            title: "Share to Add",
            description: "Found something on Netflix, Prime Video, or Apple TV? Share it directly to add to your watchlist."
        ),
        OnboardingPage(
            icon: "icloud",
            title: "Syncs Everywhere",
            description: "Your watchlist syncs automatically across all your devices using iCloud."
        ),
        OnboardingPage(
            icon: "app.connected.to.app.below.fill",
            title: "Works Everywhere",
            description: "Available on iPhone, iPad, and Mac. Your watchlist follows you wherever you go."
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            #if os(iOS)
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    pageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            #else
            // macOS: no page style, use simple transition
            pageView(pages[currentPage])
                .animation(.easeInOut, value: currentPage)
            #endif
            
            // Page indicator
            HStack(spacing: 8) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, _ in
                    Circle()
                        .fill(currentPage == index ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            .padding(.bottom, 24)
            
            // Buttons
            HStack {
                Button("Skip") {
                    onComplete()
                }
                .foregroundColor(.secondary)
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button(currentPage == pages.count - 1 ? "Get Started" : "Next") {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        onComplete()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
            
            // Keyboard navigation for macOS
            #if os(macOS)
            .onKeyPress(.leftArrow) {
                if currentPage > 0 {
                    withAnimation { currentPage -= 1 }
                }
                return .handled
            }
            .onKeyPress(.rightArrow) {
                if currentPage < pages.count - 1 {
                    withAnimation { currentPage += 1 }
                }
                return .handled
            }
            #endif
        }
        .background(background)
        #if os(macOS)
        .frame(width: 600, height: 500)
        #endif
    }
    
    private var background: some View {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }
    
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
