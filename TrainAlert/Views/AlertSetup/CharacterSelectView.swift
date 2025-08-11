//
//  CharacterSelectView.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI

struct CharacterSelectView: View {
    
    // MARK: - Properties
    
    @ObservedObject var setupData: AlertSetupData
    let onNext: () -> Void
    let onBack: () -> Void
    
    // MARK: - State
    
    @State private var selectedStyle: CharacterStyle
    @State private var previewMessage: String = ""
    @State private var isGeneratingPreview = false
    
    // MARK: - Init
    
    init(setupData: AlertSetupData, onNext: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.setupData = setupData
        self.onNext = onNext
        self.onBack = onBack
        self._selectedStyle = State(initialValue: setupData.characterStyle)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Character Selection Grid
                    characterSelectionGrid
                    
                    // Preview Section
                    previewSection
                    
                    // Navigation Buttons
                    navigationButtons
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color.backgroundPrimary)
            .navigationBarHidden(true)
        }
        .onAppear {
            generatePreviewMessage()
        }
        .onChange(of: selectedStyle) { _ in
            generatePreviewMessage()
        }
    }
    
    // MARK: - Views
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.trainSoftBlue)
                }
                .padding(.trailing, 8)
                
                Spacer()
                
                Text("キャラクター選択")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                // Placeholder for symmetry
                Color.clear
                    .frame(width: 32, height: 32)
            }
            
            // Progress indicator
            ProgressView(value: 3, total: 4)
                .progressViewStyle(LinearProgressViewStyle(tint: .trainSoftBlue))
                .frame(height: 4)
                .clipShape(Capsule())
        }
    }
    
    private var characterSelectionGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("通知スタイル")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Text("お好みの通知スタイルを選択してください")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(CharacterStyle.allCases, id: \.rawValue) { style in
                    CharacterStyleCard(
                        style: style,
                        isSelected: selectedStyle == style,
                        onTap: {
                            selectCharacterStyle(style)
                        }
                    )
                }
            }
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("プレビュー")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Text("選択したスタイルでの通知メッセージ例")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.warmOrange)
                        
                        Text("通知プレビュー")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        if isGeneratingPreview {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .trainSoftBlue))
                                .scaleEffect(0.7)
                        }
                    }
                    
                    Divider()
                        .background(Color.textSecondary.opacity(0.3))
                    
                    if previewMessage.isEmpty && !isGeneratingPreview {
                        Text(selectedStyle.fallbackMessages.trainAlert.body.replacingOccurrences(
                            of: "{station}",
                            with: setupData.selectedStation?.name ?? "渋谷駅"
                        ))
                            .font(.body)
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text(previewMessage)
                            .font(.body)
                            .foregroundColor(.textPrimary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(16)
            }
        }
    }
    
    private var navigationButtons: some View {
        VStack(spacing: 12) {
            PrimaryButton(
                "次へ",
                size: .fullWidth
            ) {
                saveSelection()
                onNext()
            }
            
            SecondaryButton(
                "戻る",
                size: .fullWidth
            ) {
                onBack()
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Computed Properties
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }
    
    // MARK: - Methods
    
    private func selectCharacterStyle(_ style: CharacterStyle) {
        selectedStyle = style
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func saveSelection() {
        setupData.characterStyle = selectedStyle
    }
    
    private func generatePreviewMessage() {
        guard let stationName = setupData.selectedStation?.name else {
            previewMessage = selectedStyle.fallbackMessages.trainAlert.body.replacingOccurrences(of: "{station}", with: "渋谷駅")
            return
        }
        
        isGeneratingPreview = true
        previewMessage = ""
        
        // For now, use fallback message. In the future, this could call OpenAI API
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.previewMessage = self.selectedStyle.fallbackMessages.trainAlert.body
                .replacingOccurrences(of: "{station}", with: stationName)
            self.isGeneratingPreview = false
        }
    }
}

// MARK: - Character Style Card

struct CharacterStyleCard: View {
    let style: CharacterStyle
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Character Icon
                characterIcon
                
                // Character Name
                Text(style.displayName)
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                
                // Character Description
                Text(characterDescription)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                // Selection Indicator
                if isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundColor(.success)
                        
                        Text("選択中")
                            .font(.caption)
                            .foregroundColor(.success)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 120)
            .padding(16)
            .background(isSelected ? Color.backgroundCard : Color.backgroundSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.trainSoftBlue : Color.clear,
                        lineWidth: 2
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var characterIcon: some View {
        Group {
            switch style {
            case .gyaru:
                Text("💅")
                    .font(.system(size: 32))
            case .butler:
                Text("🤵")
                    .font(.system(size: 32))
            case .kansai:
                Text("🗣️")
                    .font(.system(size: 32))
            case .tsundere:
                Text("😤")
                    .font(.system(size: 32))
            case .sporty:
                Text("💪")
                    .font(.system(size: 32))
            case .healing:
                Text("🌸")
                    .font(.system(size: 32))
            }
        }
        .frame(width: 40, height: 40)
    }
    
    private var characterDescription: String {
        switch style {
        case .gyaru:
            return "明るく元気な口調"
        case .butler:
            return "丁寧で格式高い口調"
        case .kansai:
            return "親しみやすい関西弁"
        case .tsundere:
            return "ツンデレな口調"
        case .sporty:
            return "ハキハキ体育会系"
        case .healing:
            return "穏やかで癒し系"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CharacterSelectView_Previews: PreviewProvider {
    static var previews: some View {
        let setupData = AlertSetupData()
        setupData.selectedStation = StationModel(
            id: "test",
            name: "渋谷駅",
            latitude: 35.6580,
            longitude: 139.7016,
            lines: ["JR山手線"]
        )
        
        return CharacterSelectView(
            setupData: setupData,
            onNext: {},
            onBack: {}
        )
        .preferredColorScheme(.dark)
    }
}
#endif
