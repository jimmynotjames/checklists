//
//  ChecklistView.swift
//  checklists
//
//  Created by Jimmy Ho on 12/9/24.
//  Copyright © 2024 Jimmy Ho. All rights reserved.
//

import SwiftUI
import RealmSwift

struct ChecklistView: View {
  @ObservedRealmObject var checklist: Checklist

  var body: some View {
    VStack {
      ChecklistHeaderView(checklist: checklist)
      Spacer()
    }
    .padding(.leading, 16.0)
  }
}

// For completion icon, title and general notes.
struct ChecklistHeaderView: View {
  @ObservedRealmObject var checklist: Checklist

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        CircularPercentStatusIcon(iconType: .header, percentageComplete: checklist.percentageComplete)
        TextField("Name", text: $checklist.name)
          .font(.title)
          .fontWeight(.bold)
          .foregroundColor(Color.black)
        Spacer()
      }
      TextEditor(text: Binding(
        get: { checklist.notes ?? "" },
        set: { text in
          guard let checklist = checklist.thaw() else { fatalError("checklist.thaw() failed") }
          DBManager.write {
            checklist.notes = (text.trimmed() == "") ? nil : text
          }
        }
      ))
        .font(.headline)
        .fontWeight(.regular)
        .foregroundColor(Color.black)
        .lineLimit(3, reservesSpace: true)
        .multilineTextAlignment(.leading)
    }
  }
}

#Preview {
  let realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "Preview"))
  SampleData.populateWithSampleData(realm: realm)
  return ChecklistView(checklist: realm.objects(Group.self).first!.checklists.first!)
}
